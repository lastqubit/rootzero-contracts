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
    constructor(address commander) CommandHost(commander) {}

    function deposit(bytes32 account, bytes32 asset, uint amount) internal override {
        uint balance = creditTo(account, asset, amount);
        emit Balance(account, asset, balance, int(amount), depositId);
    }
}
```

`CommandHost` requires a nonzero commander and accepts command calls only from
that address. It has no built-in admin commands, peer registry, guardians,
inbound introduction endpoint, generic execution command, or native-token
receive function. Use `Host` instead when the application needs those advanced
facilities; its commands accept the commander, the host itself, and explicitly
authorized host callers.

Both host types introduce themselves during deployment when the commander is a
contract. That commander must implement `introduce(uint,uint)` and accept the
call, otherwise deployment reverts. EOA commanders do not receive an
introduction call.

Host contracts are designed for fresh deployment rather than proxy upgrades.
Releases may change inheritance storage layout, immutable configuration, and
encoded identity formats; storage compatibility across versions is not
supported.

Commands using trusted outbound `NodeCalls` also require a `TrustAccess`
implementation. The advanced `Host` supplies one through its composed node access, while
`CommandHost` deliberately does not. A minimal host can explicitly compose a
custom trust policy, or a command that intentionally targets arbitrary nodes
can inherit `RawNodeCalls` instead.

Deploy it with your own address as commander and you can call its commands
directly. A input is a run of binary blocks — here, a single `#amount` block
asking to deposit an asset (the encoders are a few lines each; see
[`test/helpers/blocks.ts`](test/helpers/blocks.ts) for reference
implementations):

```ts
const host = await ethers.deployContract("ExampleHost", [deployer.address]);

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
position. The full schema language is specified in
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
for batching. Readers interpret a zero group byte as group size 1 when the lane
is non-empty.

Off-chain, building a batch is concatenation. Using the reference encoders from
[`test/helpers/blocks.ts`](test/helpers/blocks.ts):

```ts
import { concat } from "ethers";
import { encodeAmountBlock } from "./helpers/blocks";

const input = concat([
  encodeAmountBlock(usdc, 250_000_000n),
  encodeAmountBlock(dai, 250n * 10n ** 18n),
]);
// deposit(input) returns two #balance blocks in its state output and an
// empty transaction output
```

Everything downstream keeps this shape: commands loop over input blocks,
posting loops over transactions, pipelines loop over steps. Batching is
never a special case.

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

where `type` packs `[uint16 representation][uint8 category][uint8 subtype]`. A
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

Trust is explicit and minimal. Each host has an immutable **commander**
address fixed at construction, from which its **admin account** is derived.
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

Every command returns two block streams: `state`, which is threaded into the
next pipeline step, and `transactions`, which contains `#transaction` blocks
for the pipeline host to post outside the state lane. Either stream may be
empty.

State is linear, not optional ambient context. A command is responsible for
the entire state stream it receives: it must validate and consume it, transform
and return it, forward it intact, or revert. A command must never succeed while
silently ignoring or dropping supplied state. Commands that declare
`Specs.Empty` state therefore reject any non-empty state, while commands that
accept state validate the complete stream against their declared state schema.
This is especially important for `#position`, because dropping a position could
silently discard both live value and an outstanding debt requirement.

The input carries instructions; the state carries live value. While a
sequence of commands executes, `#balance`, `#custody`, and `#position` blocks
in the state are the value being moved — produced by one command, consumed by
the next. A position carries an asset-liability pair as
`{ asset, amount, liability, debt }`.

`#position` is general live state rather than a lending-specific debt record.
It pairs value acquired or controlled with value owed or required. A command
may preserve or replace either side and return the resulting position for the
next step; `settle` terminally consumes the pair. This supports swaps,
borrowing, refinancing, collateral changes, callback obligations, cross-host
claims, fees, netting, and other multi-step operations. A position is a
transient representation and does not itself create or erase an obligation
recorded by an external system.

The standard `Deposit` mixin shows the canonical shape: open and validate both
command lanes, loop the batch, call the hook, and write the output run:

```solidity
function deposit(
    bytes calldata context
) external onlyCommand returns (bytes memory, bytes memory) {
    Execution memory exec = openCommand(context, descriptor, 0);

    while (exec.more()) {
        (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
        deposit(exec.account, asset, amount); // host policy hook
        exec.outputBalance(asset, amount);
    }

    return closeCommand(exec);
}
```

A command announces itself when the host is deployed. Its constructor emits a
discovery event carrying a packed descriptor with the input, state, and output
lanes, derived group sizes, and flags, plus a human-readable label:

```solidity
abstract contract MyCommand is CommandBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("myCommand", Specs.Empty, Specs.Amount, Specs.Balance, 0, 0);
    }

    function myCommand(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 0);
        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            // Apply command-specific behavior for this group.
            exec.outputBalance(asset, amount);
        }
        return closeCommand(exec);
    }
}
```

The final argument is a packed flags byte. Pass `0` for an ordinary endpoint,
or compose values such as `Flags.Funded`, `Flags.Admin`, and
`Flags.AdminFunded` from the command or endpoint package entry point.

The standard commands cover the common ledger movements: `deposit` and
`depositPayable` (external funds in), `settlePayable` (funded settlement),
`withdraw` and `burn` (funds out),
`debitAccount` and `creditAccount` (internal movements), `payout` (deliver
state to other accounts), `allocate` (turn balance state into custody),
`provision` (provision custody from an external allocation), `settle` (consume
asset-liability position state), `relayPayable` (relay a pipeline without
state), and `relayBalancePayable` (relay balance state and a pipeline to another
portal).

## Pipelines

A single command is rarely the whole story. A pipeline is a run of `#step`
blocks executed in order within one transaction:

```txt
step { uint cmd, uint resources, #bytes as input }
```

Each step names a command, the resources it may spend, and its input.
The returned state threads into the next command and the final state must be
empty. Returned transactions do not enter the state lane; the pipeline passes
each decoded transaction to the shared posting implementation before
running the next step. This is the core of `Pipeline.pipe`:

```solidity
while (cur.more()) {
    (uint cmd, uint resources, bytes calldata input) = cur.unpackStep();
    Reader memory transactions;
    (state, transactions.source) = dispatch(
        cmd,
        account,
        state,
        input,
        budget.useResourceValue(resources)
    );
    while (transactions.more()) {
        (bytes32 from, bytes32 to, bytes32 asset, uint amount) = transactions.unpackTransaction();
        post(from, to, asset, amount);
    }
}
if (state.length != 0) revert UnexpectedState();
```

A transfer, for instance, is a two-step pipeline: `debitAccount` turns an
`#amount` input into `#balance` state, and `payout` consumes that state
toward a recipient. Because a pipeline is just blocks, it is also the unit of
command batching — and `resources` is a chain-specific word interpreted by the
portal adapter (on EVM, the low 128 bits are native value in wei, drawn from a
shared budget), so the same pipeline bytes are meaningful to every port.

Hosts that implement a pipeline locally can inherit `DebitAccountInternal`,
`CreditAccountInternal`, and `SettleInternal` to advertise the canonical command
endpoints while routing their local command IDs through `executeDebitAccount`,
`executeCreditAccount`, and `executeSettle`. These adapters consume the
memory-backed pipeline state directly and avoid an external self-call. Pass the
step value into each adapter; all three reject nonzero value because the
commands are non-funded.

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

Ports are the host-to-host surfaces, callable only by trusted peer hosts. The two
central ones are batches all the way down:

- `portPost` consumes `transaction { bytes32 from, bytes32 to, bytes32 asset,
  uint amount }` blocks, debiting `from` and crediting `to` per
  block — how two hosts post transactions between their ledgers.
- `portRequestAsset` consumes `amount { bytes32 asset, uint amount }` blocks and
  passes the authenticated peer, asset, and amount to a host hook. The hook
  validates asset support and applies the host's request and transfer policy.
- `portRequestAllowance` consumes the same amount blocks and lets the
  authenticated peer request an asset allowance. The hook decides what
  allowance, if any, to grant.
- `portPipePayable` consumes `context` blocks, each carrying an account, an
  initial state, and a run of steps — a complete pipeline delivered by another
  host, executed locally against the port call's shared value budget.

This is also the cross-portal mechanism. `relayPayable`, `relayBalancePayable`,
or `portDispatchPayable` wraps a pipe and addresses it to a portal, commonly the destination host ID;
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
  `Settlement`, `Pipeline`, `Portal`, validator
- `@rootzero/contracts/Commands.sol` — `CommandBase`, `Execution`, `Flags`,
  codec helpers, and shared value types for authoring custom commands
- `@rootzero/contracts/Endpoints.sol` — command, admin, port, guard, and query
  mixins, their hooks, and `Flags`
- `@rootzero/contracts/Codec.sol` — `Blocks`, calldata `Cur`/`Cursors`, memory
  `Reader`/`Readers`, `Writers`, `Schemas`, `Descriptors`, `Flags`, `Keys`, and
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
