# rootzero

rootzero is a protocol for building **hosts**: contracts that expose a uniform
set of endpoints over accounts and assets — commands that change state,
queries that read it, and port links that connect hosts to each other, on the
same chain or across chains.

This repository is `@rootzero/contracts`, the Solidity library for the EVM port
of the protocol: the base contracts, block codecs, and helpers that rootzero
applications compose.

Two decisions shape everything below. First, all data that crosses a host
boundary is encoded in one binary block format, so a input means the same
bytes on every chain. Second, every surface operates on *runs* of blocks rather
than single values, so batching is the default, not a feature added later. This
guide introduces the protocol bottom-up: blocks, then identities, then hosts
and the endpoints built on top of them.

## Quick Start

Scaffold a ready-to-run Hardhat project, or add the library to an existing
one:

```bash
npx create-rootzero@latest my-app
# or
npm install @rootzero/contracts
```

A minimal commander-only host composes `CommandHost` with the endpoints it
needs and implements their policy hooks:

```solidity
// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandHost, Balances } from "@rootzero/contracts/Core.sol";
import { Deposit } from "@rootzero/contracts/Endpoints.sol";

contract ExampleHost is CommandHost, Balances, Deposit {
    constructor(uint commander) CommandHost(commander) {}

    function deposit(bytes32 account, bytes32 asset, uint amount) internal override {
        uint balance = creditTo(account, asset, amount);
        emit Balance(account, asset, balance, int(amount), depositId);
    }
}
```

`CommandHost` requires a nonzero local commander host ID and accepts command
calls only from its embedded native caller. It has no built-in admin commands, peer registry, guardians,
inbound introduction endpoint, generic execution command, or native-token
receive function. Use `Host` instead when the application needs those advanced
facilities; its commands accept the commander, the host itself, and explicitly
authorized host callers.

Both host types introduce themselves during deployment when the native target
encoded by the commander host ID is a contract. That commander must implement
`introduce(uint,uint)` and accept the call, otherwise deployment reverts. Host
IDs encoding EOAs do not receive an introduction call.

Host contracts are designed for fresh deployment rather than proxy upgrades.
Releases may change inheritance storage layout, immutable configuration, and
encoded identity formats; storage compatibility across versions is not
supported.

Commands using trusted outbound `NodeCalls` also require a `TrustAccess`
implementation. The advanced `Host` supplies one through its composed node access, while
`CommandHost` deliberately does not. A minimal host can explicitly compose a
custom trust policy, or a command that intentionally targets arbitrary nodes
can import the free raw-call helpers instead.

Deploy it with the local host ID encoding your native identity as commander and you can call its commands
directly. A input is a run of binary blocks — here, a single `#amount` block
asking to deposit an asset (the encoders are a few lines each; see
[`test/helpers/setup.ts`](test/helpers/setup.ts) and
[`test/helpers/blocks.ts`](test/helpers/blocks.ts) for reference
implementations):

```ts
const commander = await hostId(deployer.address);
const host = await ethers.deployContract("ExampleHost", [commander]);

const account = encodeUserAccount(user.address); // receiving account
const input = encodeAmountBlock(asset, 100n); // what to deposit
await host.deposit({ account, state: "0x", input: input }); // emits Balance
```

The rest of this guide explains the ideas this example leans on — blocks, IDs,
hosts, commands — and the surfaces built on top of them.

## Blocks

Every input, response, and piece of in-flight state is a stream of typed
blocks. A block is a four-byte key, a four-byte big-endian length, and a
payload:

```txt
[bytes4 key][uint32 payloadLen][payload]
```

The key is usually `bytes4(keccak256("#name"))`, and the payload layout is
described by a schema body published under an alias. For example, the standard
`amount` block that requests a deposit:

```txt
amount { bytes32 asset, uint amount }
```

is 72 bytes on the wire: an 8-byte header followed by two big-endian 32-byte
fields. There is no ABI encoding and no chain-specific type anywhere in the
format — field types are chain-neutral integers, bytes, and booleans. A deposit
input built for an EVM host is byte-for-byte the input a CosmWasm or Solana
port would parse; what differs per chain is how a host *resolves* the
identifiers inside, never how the bytes are laid out.

Schemas can express more than flat fields: a block may contain any number of
nested child blocks (`#bytes as payload` names raw dynamic bytes), items can be
marked `maybe` when their empty form is accepted or `many` when they form a
list, and aliases and dotted field paths give off-chain tooling presentation
names without changing a single byte on the wire. Declared child headers are
always present; a zero payload length represents an empty block. An `at N` hint
can reposition one field in off-chain presentation without changing its wire
position. Qualified schema names such as `relay.input` describe the raw
contents of aliased `#bytes` fields; schemas emitted locally by the active host
take precedence over trusted-context and standard schemas with the same name.
Standard block aliases are intrinsic protocol metadata: indexers resolve names
such as `balance`, `step`, and `context` from their standard keys even when no
named schema annotation is emitted.
The full schema language is specified in
[`docs/Schema.md`](https://github.com/lastqubit/rootzero-evm/blob/main/docs/Schema.md). The standard block schemas live in
`Schemas` and their runtime keys in `Keys` (both via
`@rootzero/contracts/Codec.sol`).

A rare top-level list is published as a custom schema consisting of one item,
such as `many #asset` or `{ many #asset }`. Its context-local schema key becomes
the outer block key accepted by the endpoint; a list alongside sibling items
continues to use the generic `#list` key.

## Batches

A input is not a single struct; it is a run of blocks. One `#amount` block
asks for one deposit, five blocks ask for five, and the code path is identical
— every endpoint parses with a cursor and loops until the stream is exhausted.
The descriptor lane key is the prime item: it is the block type that may repeat
for batching. Descriptor decoding interprets a zero group byte as group size 1
when the lane is non-empty.

Off-chain, building a batch is concatenation. Using the reference encoders from
[`test/helpers/blocks.ts`](test/helpers/blocks.ts):

```ts
import { concat } from "ethers";
import { encodeAmountBlock } from "./helpers/blocks";

const input = concat([
  encodeAmountBlock(usdc, 250_000_000n),
  encodeAmountBlock(dai, 250n * 10n ** 18n),
]);
// deposit(input) returns two #balance blocks and zero native budget credit
```

Everything downstream keeps this shape: commands loop over input blocks,
posting ports loop over transactions, and pipelines loop over steps. Batching
is never a special case.

## IDs, Accounts, Assets, and Nodes

Everything the protocol touches - accounts, assets, chains, hosts, endpoints -
is identified by one 32-byte word. The first byte selects the convention:

- `0x00`: opaque ID, encoded as `0x00 || bytes31(hash)`. The hash preimage is
  not recoverable from the ID; use a lookup table or witness data when the
  native account, asset metadata, or node target is needed.
- nonzero: structured ID. The value can be deconstructed according to its
  layout.

Opaque preimages start with:

```txt
[uint8 formatHash][payload...]
```

Only the first byte is protocol-level convention for now. `0x01` means
keccak256. The remaining payload format is host/domain-specific until a future
standard defines it.

The field supplies the role for opaque IDs: a `bytes32 asset` with first byte
`0x00` is still an asset, but its native metadata must come from lookup or
witness data. The Solidity helpers below construct and deconstruct structured
EVM IDs.

Structured EVM IDs use:

```txt
[uint32 type][uint32 chainid][192-bit payload]
```

where `type` packs
`[uint8 representation][uint8 category][uint8 subtype][uint8 flags]`. A
structured ID announces what it is (an account, an asset, a node) and which
chain it lives on, and the payload usually embeds the underlying address. User
accounts are chain-agnostic, while admin accounts are chain-local. Guardians
are normal user accounts assigned a host-specific role.
Assets are unique IDs in the same single-word form as accounts and nodes.
Nodes are hosts, commands, ports, queries, and guards.

Opaque asset declarations use `Asset(host, asset, preimage)`. The preimage
starts with a one-byte format/hash tag, letting offchain indexers or witnesses
verify and resolve `0x00 || bytes31(hash(preimage))` assets. `0x01` means
keccak256.

The `Utils.sol` entry point provides the constructors and inspectors:

```solidity
bytes32 account = Accounts.toUser(msg.sender); // chain-agnostic user account
bytes32 asset = Assets.toErc20(tokenAddress);  // ERC-20 asset ID
uint hostId = Nodes.toHost(address(this));       // host node ID
bytes32 opaque = Ids.toKeccak(preimage);  // 0x00-prefixed opaque ID
```

## Hosts

A host is one contract assembled from mixins. The base `Host` brings access
control and the admin surface (authorize, unauthorize, appoint, dismiss,
annotate, executePayable) plus the guardian `revoke` action; you add the
endpoints you need and the policy hooks they require. Keeping a ledger is
optional: the `Balances` mixin provides one, but a host can just as well
implement commands that hold no persistent state in the host at all —
forwarding funds elsewhere, or operating only on the state threaded through a
pipeline.

The built-in surface is also available as two independent feature bundles:
`Admins` provides annotate, authorize, unauthorize, and executePayable;
`Guardians` provides appoint, dismiss, and node revocation. Hosts that implement
the allowance hook can additionally inherit the opt-in `RevokeAllowance` guard,
which accepts `hostAsset { uint host, bytes32 asset }` entries and always applies
a zero allowance. The full `Host` composes
both, while smaller hosts can inherit either bundle separately.

Trust is explicit and minimal. Each host receives an immutable **commander host
ID** at construction. The EVM port validates that it is local, extracts its
native address internally for caller checks, and derives the **admin account**
from that native identity.
Other contracts become callers only when their node ID is authorized into the
host's trusted set, and **guardians** are accounts allowed to take protective
actions. At deployment, a host introduces itself to its commander, which is how
host topology becomes discoverable.

The `ExampleHost` in the quick start shows the resulting split, and it runs
through the whole library: mixins implement the protocol mechanics (parsing,
batching, discovery events), and small virtual hooks let the host decide
policy — where funds come from, how the ledger is keyed, what gets emitted.

## Commands

Commands are the write endpoints. Every command receives the same context:

```solidity
struct CommandContext {
    bytes32 account; // acting account
    bytes state;     // block stream produced by the previous command
    bytes input;     // block stream for this invocation
}
```

Every command returns a `state` block stream and a trusted native `credit`.
State is threaded into the next pipeline step, while credit replenishes the
shared pipeline budget without validation against forwarded call value.
Command trust is the authority boundary.

State is linear, not optional ambient context. A command is responsible for
the entire state stream it receives: it must validate and consume it, transform
and return it, forward it intact, or revert. A command must never succeed while
silently ignoring or dropping supplied state. Descriptor schemas remain
discovery metadata; the command's decoding and loop implementation defines its
runtime lane semantics. A command that does not consume supplied state rejects
it when closing, while `takeRawState` explicitly consumes an intact forwarded
state lane.
This is especially important for `#debt` and `#position`, because dropping
either could silently discard an outstanding debt requirement.

The input carries instructions; the state carries live value. While a sequence
of commands executes, `#balance`, `#debt`, `#custody`, and `#position` blocks in
the state are the value being moved — produced by one command, consumed by the
next. Balance carries `{ asset, amount }`, debt carries `{ liability, debt }`,
and position carries their flat combination
`{ asset, amount, liability, debt }`.

Either side of a position may be absent. An absent asset side is encoded as
`asset = 0, amount = 0`; an absent liability side is encoded as
`liability = 0, debt = 0`. This mirrors transaction blocks, where a zero `from`
or `to` omits that side of the transfer. A one-sided position remains useful
when a command must preserve position-shaped state for later composition;
otherwise the narrower `#balance` or `#debt` block expresses the same live
value more directly.

`#debt` and `#position` are general live state rather than persisted
lending-specific debt records. Debt carries value owed or required; position
pairs that liability with value acquired or controlled. A command may preserve
or replace either side and return the resulting state for the next step;
`settle` terminally consumes a position pair. This supports swaps,
borrowing, refinancing, collateral changes, callback obligations, cross-host
claims, fees, netting, and other multi-step operations. Debt and position are
transient representations and do not themselves create or erase an obligation
recorded by an external system.

The standard `Deposit` mixin shows the canonical shape: open the execution,
decode its active input lane, call the hook, and write the output run:

```solidity
function deposit(
    bytes calldata context
) external onlyCommand returns (bytes memory, uint) {
    Execution memory exec = openCommand(context, descriptor);

    while (exec.more()) {
        (bytes32 asset, uint amount) = exec.unpackAmount();
        deposit(exec.account, asset, amount); // host policy hook
        exec.outputBalance(asset, amount);
    }

    return exec.close();
}
```

A command announces itself when the host is deployed. Its constructor emits a
discovery event carrying a packed descriptor with the input, state, and output
lanes, derived group sizes, and flags, plus a human-readable label:

```solidity
abstract contract MyCommand is CommandBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("myCommand", Specs.Empty, Specs.Amount, Specs.Balance, 0);
    }

    function myCommand(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);
        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount();
            // Apply command-specific behavior for this group.
            exec.outputBalance(asset, amount);
        }
        return exec.close();
    }
}
```

The final argument is a packed flags byte. Pass `0` for an ordinary endpoint,
or compose values such as `Flags.Funded`, `Flags.Admin`, and
`Flags.AdminFunded` from the command or endpoint package entry point.
The same flags byte is copied into the endpoint ID, keeping runtime behavior and
published descriptor metadata aligned. `Flags.Handoff` marks a command that
takes ownership of the remaining pipeline, while `Flags.HandoffFunded` combines
handoff behavior with native-value funding;
bit 6 remains endpoint-defined, and bits 2 through 5 remain reserved.

The standard commands cover the common ledger movements: `bootstrap` (source
an initial balance and native-value budget), `cashout` (withdraw native
`#balance` state), `deposit` and
`depositPayable` (external funds in), `settlePayable` (funded settlement),
`withdraw` and `burn` (funds out),
`debitAccount` and `creditAccount` (internal movements), `payout` (deliver
state to other accounts), `allocate` (turn balance state into custody),
`provision` (provision custody from an external allocation), `settle` (consume
asset-liability position state), `repay` and `repayPayable` (consume standalone
debt state), `repayPosition` and `repayPositionPayable` (repay a position's debt
and return its asset as balance state), `relayPayable` (relay a pipeline without
state), and `relayBalancePayable` (relay balance state and a pipeline to another
portal).

## Pipelines

A single command is rarely the whole story. A pipeline is a run of `#step`
blocks executed in order within one transaction:

```txt
step { uint cmd, uint value, #bytes as input }
```

Each step names a command, the native value it may spend, and its input.
The returned state threads into the next command and the final state must be
empty. Each returned native credit replenishes the budget before running the
next step, allowing one command to fund later commands. The standard
`bootstrap` command consumes a stream of
`#bootstrap { bytes32 asset, uint amount, uint budget }` requests and atomically
debits each asset through the standard account hook, introduces matching
`#balance` state, and debits each nonzero budget contribution from the account's
native asset through the same hook. Its pipeline-local implementation uses assigned step value first when
bootstrapping the native asset, debits any remainder from the account, and
returns unused assigned value as credit. Bootstrap is registered with command
metadata but is only executable through local pipeline execution. This is the core of
`Pipeline.pipe`:

```solidity
uint cursor;
assembly ("memory-safe") {
    cursor := or(steps.offset, shl(32, add(steps.offset, steps.length)))
}
while (uint32(cursor) < uint32(cursor >> 32)) {
    uint cmd;
    uint value;
    (cmd, value, cursor) = takeStep(cursor);
    if (value > budget) revert InsufficientValue();
    unchecked { budget -= value; }
    (state, value, cursor) = run(cmd, account, state, value, cursor);
    budget += value;
}
if (state.length != 0) revert UnexpectedState();
```

`Pipeline.pipe` takes the available native-value budget as a `uint` and returns
the remaining budget after every step has executed. The enclosing entrypoint
settles that final value once.

The EVM pipeline is deliberately coupled to the canonical wire layout for gas
efficiency. It extracts command selectors, targets, and flags directly from
command IDs and writes CONTEXT, BYTES, and RELAY blocks directly in assembly.
Any change to those ID fields or block encodings must update `Pipeline` at the
same time; the general node and block helpers are not used on this hot path.

A handoff command retains the ordinary command subtype and carries
`Flags.Handoff` in both its ID and descriptor. The reserved handoff envelope is:

```txt
relay { #bytes as input, #bytes as steps }
```

`input` is the handoff STEP's ordinary command input, while `steps` is the
untouched remainder of the original pipeline. `Pipeline.pipe` constructs this
envelope automatically for commands carrying `Flags.Handoff`, calls the command,
and stops executing the transferred continuation locally. Pipeline authors
therefore encode only the command's ordinary input in the handoff STEP. Relay
implementations can publish a qualified `relay.input` schema to describe how
offchain tooling should decode that otherwise opaque byte payload. The standard
relay commands pass this input to their transport hook alongside a fully
constructed canonical `#context` containing the account, forwarded state, and
remaining steps, plus the handoff command's funds. The transport can therefore
forward the context directly without reconstructing its protocol payload.

Handoff has four operational rules:

- A host-local `execute` hook must return `handled = false` for handoff command
  IDs. The hook sees only ordinary STEP input; delegation lets `Pipeline`
  construct the RELAY envelope containing the continuation.
- Handoff transfers STEP bytes, not the pipeline's complete native-value
  budget. The handoff command receives its assigned STEP value. Returned credit
  rejoins the source budget, and the enclosing source entrypoint settles the
  final remainder normally.
- The handoff command must consume or forward the current state and return empty
  state. Because the continuation is no longer executed locally, returned
  non-empty state fails pipeline finalization with `UnexpectedState`.
- A transport that completes asynchronously should relinquish only state that
  is safe before destination success is known. The standard relay commands are
  intended for empty or balance state; debt, position, and similarly fallible
  state must not be relayed this way.

A transfer, for instance, is a two-step pipeline: `debitAccount` turns an
`#amount` input into `#balance` state, and `payout` consumes that state
toward a recipient. Because a pipeline is just blocks, it is also the unit of
command batching. A step's plain `uint value` is drawn directly from the shared
native-value budget. Transport envelopes retain separate opaque, packed
chain-specific `resources` fields for adapters that also need gas or runtime
parameters. A `resources` word is never itself native value; EVM adapters use
`useResourceValue` to extract its low 128-bit value lane before spending it.

Hosts that implement a pipeline locally can inherit `Bootstrap`,
`ExecuteCashout`, `ExecuteDebitAccount`, `ExecuteCreditAccount`,
`ExecuteSettle`, and
`ExecuteRepay` to register canonical command metadata while executing
their local command IDs through `executeBootstrap`, `executeCashout`,
`executeDebitAccount`, `executeCreditAccount`, `executeSettle`, and
`executeRepay`. The bootstrap and debit adapters decode fixed-stride calldata
input directly; cashout, credit, settle, and repay decode memory-backed pipeline
state. All return `handled = true` and avoid an
external self-call. The host's `execute` hook must authorize a command before
returning true. Returning `handled = false` delegates a local command to its
trusted normal external entrypoint. Pass the step value into each adapter.
Bootstrap is pipeline-local rather than an
externally callable command and may consume value for native-asset balance;
the other five reject nonzero value because those commands are non-funded.

Positions also support backward-composed pipelines. In an exact-output route,
the asset side can represent the desired result while the liability side
represents the value currently required upstream. Each hop consumes one
position, fulfills or transforms its current requirement, and returns the next
position:

```txt
position(C, 100, C, 100)
→ position(C, 100, B, 50)
→ position(C, 100, A, 25)
→ settle
```

This is backward composition, not backward execution: `#step` blocks still
execute forward in their encoded order. Exact-output routing is only one use;
other commands may transform the asset side, the liability side, or both.

## Queries

Queries are the read endpoints: view functions that take a block-stream input
and return a block-stream response, with the same batch shape as commands. The
standard `getBalances` query takes a run of positions and answers each one in
order:

```txt
input:  accountAsset { bytes32 account, bytes32 asset }
response: accountAmount { bytes32 account, bytes32 asset, uint amount }
```

Like commands, every query announces a descriptor at deployment; tooling resolves
the descriptor's lanes through the published block schemas.

## Ports

Ports are the host-to-host surfaces, callable only by trusted peer hosts. By
default, trusting a peer means the host has verified that peer and permits it to
use the functionality of every port the host exposes without another policy
decision inside each port. A host that needs narrower capabilities can add
per-port or per-operation checks in its hook implementations, or expose custom
ports with a different access model.

The central ports are batches all the way down:

- `portPost` consumes `transaction { bytes32 from, bytes32 to, bytes32 asset,
  uint amount }` blocks, debiting `from` and crediting `to` per
  block — how two hosts post transactions between their ledgers.
- `portRequestAsset` consumes `amount { bytes32 asset, uint amount }` blocks and
  passes the authenticated peer, asset, and amount to a host hook. The hook
  validates asset support and applies the host's request and transfer policy.
- `portRequestAllowance` consumes the same amount blocks and lets the
  authenticated peer set its own asset allowance through the same authoritative
  hook used by the admin allowance command.
- `portPipePayable` consumes `context` blocks, each carrying an account, an
  initial state, and a run of steps — a complete pipeline delivered by another
  host, executed locally against the port call's shared value budget.

This is also the cross-portal mechanism. `relayPayable` and
`relayBalancePayable` are handoff commands whose transport hooks decode their
own destination and resource input and forward an already constructed command
context, while `portDispatchPayable` dispatches an explicit portal payload. The
adapter wraps and addresses the destination pipe;
a bridge adapter moves the **raw
bytes**; the destination host parses them with the same cursor rules and runs
the same pipeline loop. Nothing in the payload is EVM-specific — step commands
are destination-local command IDs, and only the adapter boundary (native
transfers, address resolution, signatures) is chain-specific. The parity rule
for ports is strict: every chain's implementation must parse the same input
bytes and produce the same output bytes for every endpoint.

## Guards and Admin

Admin commands use the regular command shape but are gated to the host's admin
account: trust management (`authorize`, `unauthorize`), guardian management
(`appoint`, `dismiss`), metadata (`annotate`), optional asset gating
(`allowAssets`, `denyAssets`, `allowance`), and raw calls (`executePayable`).
Guards go the other way: direct actions guardians can take
without any command context — the default is `revoke`, which lets a guardian
drop a trusted node immediately.

## Events and Discovery

Hosts are self-describing. At deployment a host emits the ABI of every event it
uses (`EventAbi`), block schema events, endpoint descriptors, and labels for
human-readable names. State changes then follow evented
conventions: `Balance` for every ledger change and flow events (`Received`,
`Spent`, `Locked`, `Unlocked`) for value movement, each tagged with the endpoint that
caused it. An indexer can reconstruct the entire repository — endpoints,
names, access sets, balances — from logs alone, with no artifact files.

## Using the Library

Import from the package entry points rather than deep paths:

- `@rootzero/contracts/Core.sol` — `Host`, access control, `Balances`,
  `Settlement`, `ExecuteHook`, `PipeHook`, `Pipeline`, `Portal`, validator
- `@rootzero/contracts/Commands.sol` — `CommandBase`, `Execution`, `Flags`,
  codec helpers, and shared value types for authoring custom commands
- `@rootzero/contracts/Endpoints.sol` — command, admin, port, guard, and query
  mixins, their hooks (including `ExecuteHook` and `PipeHook`), and `Flags`
- `@rootzero/contracts/Codec.sol` — `Blocks`, calldata `Cur`/`Cursors`, memory
  `Memory`, `Writers`, `Schemas`, `Descriptors`, `Flags`, `Keys`, and
  `Specs`
- `@rootzero/contracts/Utils.sol` — `Ids`, `Nodes`, `Assets`, `Accounts`,
  layout and value helpers
- `@rootzero/contracts/Events.sol` — protocol event contracts

Repo layout:

- `contracts/core` — host, access control, balances, pipeline, validation
- `contracts/commands` — standard commands and admin commands
- `contracts/ports` — port surfaces for inter-host and cross-portal flows
- `contracts/guards` — guardian direct actions
- `contracts/queries` — read-only query endpoints
- `contracts/blocks` — block schema, cursor parsing, writers
- `contracts/utils` — ids, nodes, assets, accounts, layout, ECDSA
- `contracts/events` — event contracts and emitters
- `docs` — [`Schema.md`](https://github.com/lastqubit/rootzero-evm/blob/main/docs/Schema.md) (wire format and schema DSL)

Use this library to create a new rootzero host, implement a command, or reuse
the protocol's block format in tooling. It is the shared protocol foundation,
not an end-user application.
