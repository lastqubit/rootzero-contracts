# Indexing

Rootzero hosts publish discovery metadata and state changes through events so
off-chain indexers can reconstruct a repository — the catalog of endpoints,
labels, and access state, plus account balances and asset flows — from logs
alone, without contract artifacts, traces, or `eth_call`.

This document is the companion to [`Schema.md`](Schema.md): Schema.md describes
how to decode block payloads; this document describes what the log stream
guarantees, the event conventions hosts are expected to follow, and a small set
of proposed improvements. Sections marked **Proposed** are not yet implemented.

## Self-Describing ABI

Every event mixin emits `EventAbi` once from its constructor with the full ABI
string of the event it declares:

```txt
event EventAbi(string abi)
```

An indexer that replays a host's deployment logs learns the complete event ABI
of that host without artifact files. Only `EventAbi` itself must be known a
priori.

## Repository Discovery

The library guarantees the discovery layer. Each endpoint mixin emits one
discovery event from its constructor, so a host's deployment transaction
contains its full endpoint catalog:

```txt
event Endpoint(uint indexed host, uint id, uint descriptor)
```

- `descriptor` packs `[state key:4][group:1]`,
  `[input key:4][group:1]`,
  `[output key:4][min:4][max:4][hint:3][group:1]`, four reserved bytes,
  one transaction-count byte, and one flags byte.
  Flag bits 0 and 1 mean `funded` and `admin`; bits 6 and 7 are reserved for
  endpoint-defined custom flags, while bits 2 through 5 remain reserved for
  future protocol flags.
  A zero group byte means group size 1 for a non-empty lane;
  `group(lane, size)` supplies an explicit size.
  The output bounds and hint allow a writer to be initialized directly from
  the descriptor. The Solidity output decoder returns a left-aligned spec with
  its encoded group retained and its reserved fields cleared.
  `Specs.group` returns the effective group, including the zero-to-one default
  for non-empty specs.
  A top-level list uses a context-local input key whose published schema body
  consists of one `many #item`, optionally wrapped in braces; nested lists in a
  body with sibling items continue to use the generic `#list` key.
- Command, port, query, and guard endpoints all share `Endpoint`; admin commands
  are marked by the descriptor's admin flag.
- Block schema strings are published as `#schema` blocks in `Annotation` events.
  Hosts may publish additional schema claims later through the admin `annotate`
  command.

Names arrive as annotations. Each standard mixin emits a canonical label block
at construction, and the admin `annotate` command publishes mutable annotations
later:

```txt
event Annotation(uint indexed entity, bytes data)
#label { bytes32 namespace, #string as name }
```

Annotations are claims by the emitting contract: any contract may annotate any
entity, so indexers decide which emitters they trust per entity and annotation
type. Constructor label annotations emitted by the host itself are trustworthy
for that host's own endpoints. Consumers process annotation events in log order
and blocks within `data` in stream order.

`Annotation` is a policy-neutral envelope. There is no universal rule that a
later block replaces an earlier block: every annotation type defines its own
logical identity and merge behavior. A type may replace an earlier value,
accumulate distinct values, preserve every value as history, or define an
explicit revocation convention. Indexers must apply those type-specific rules
after checking the emitter they trust for that type.

The standard types currently use these rules:

- An `#action` is identified by its entity. The latest trusted action replaces
  the previous value; `Actions.None` clears the primary action classification.
- A `#label` is identified by `(entity, namespace)`. The latest trusted label
  for that identity replaces its previous value; labels in different namespaces
  coexist.
- A `#schema` is identified by `(entity, block key)`. Schemas for distinct keys
  coexist, while the latest trusted schema claim for the same key replaces the
  earlier claim.

New annotation types must document their logical identity, whether values
replace or accumulate, and how values are revoked when revocation is supported.

Host topology and access state are fully evented by the library:

```txt
event Introduction(uint indexed host, uint peer, bytes32 origin, uint blocknum)
event Node(uint indexed host, uint node, bool active)
event Guardian(uint indexed host, bytes32 account, bool active)
```

`Introduction` fires on the receiving host when a peer host introduces itself
during construction. `origin` records `tx.origin` as a chain-agnostic user
account for provenance and must not be treated as authorization. Every
node-trust change routes through `setNode` and every
guardian change through `setGuardian`, so `Node` and `Guardian` are exhaustive:
replaying them yields the exact current access sets.

All account, asset, and node IDs are 32-byte values with one top-byte rule:
`0x00` means opaque `0x00 || bytes31(hash)`, and nonzero means structured.
Structured EVM IDs use `[uint32 type][uint32 chainid][192-bit payload]`, where
`type` packs `[uint16 representation][uint8 category][uint8 subtype]`; see
`utils/Layout.sol`. Indexers can decode structured IDs directly. Opaque IDs need
host-specific lookup or witness data when the underlying account, asset
metadata, or node target is needed.
Opaque preimages start with a one-byte format/hash tag; `0x01` means
keccak256. The remaining bytes are host/domain-specific for now.

### Cold-Start Recipe

1. Start from the chain's configured commander host address. Replay its
   deployment logs: `EventAbi` gives the event ABIs,
   the discovery events give the endpoint catalog, and `Annotation` label blocks
   give names.
2. Follow `Introduction` events on the commander to enumerate hosts. The `peer`
   ID embeds the introduced host's address; the receiving `host` is the
   commander that accepted the introduction, and the peer's admin account
   derives from the commander address (`Accounts.toAdmin`).
3. For each host, repeat step 1 against its deployment logs, then replay
   `Node` and `Guardian` for live access sets.
4. Subscribe to the state events below for balances and flows.

The endpoint repository — commands, admin commands, ports, queries, and guards
with schemas, names, and access state — is fully reconstructible from logs
today. No changes are proposed to the discovery layer.

## State Events

Most state-event emission remains a host responsibility: asset and ledger
mutation flows through virtual hooks (`deposit`, `withdraw`, `burn`,
`creditAccount`, `debitAccount`, `payout`, `provision`, `allowAsset`,
`denyAsset`, ...), and the hook implementation is the layer that knows the
host's ledger policy - in particular the asset binding and the resulting
balance. Command-returned native credit replenishes the pipeline budget. The
enclosing entrypoint settles the final budget through its posting hook, so the
ledger emits one receiving event. The `create-rootzero` template
(`rootzero-evm-commander`) is the reference implementation of the remaining
host conventions.

```txt
event Balance(bytes32 indexed account, bytes32 asset, uint balance, int change, uint access)
event Positioned(bytes32 indexed account, bytes32 asset, uint amount, bytes32 liability, uint debt, uint32 action)
event Received(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)
event Spent(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)
event Locked(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)
event Unlocked(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)
event Asset(uint indexed host, bytes32 asset, bytes preimage)
event AssetStatus(uint indexed host, bytes32 asset, uint status)
event Rooted(bytes32 indexed account, uint deadline, uint value)
```

### Host Conventions

A host that wants to be indexable from logs alone must follow these rules. A
host that omits them still works on-chain, but its ledger is invisible to
log-based tooling - there is no fallback channel, because command output
(`state` and native `credit`) is return data and inputs are calldata.

**Root identity.** The trusted commander address and chain context are off-chain
configuration. Indexers derive its host ID from that address and chain ID, and
derive the native asset ID from the chain ID. A root host labels itself with an
`Annotation` containing a `#label` block. Child hosts are discovered through
`Introduction` on their commander.

**Balances.** Every ledger mutation emits `Balance` with the resulting total,
the signed change, and `access` set to the node ID of the endpoint that
performed the change. Hosts using the built-in `Balances` ledger key balances
directly by `(account, asset)`, so query results and events agree.

**Positions.** An action that exposes a resulting live position may emit
`Positioned` with both the asset and liability sides and the primary `Actions`
code that produced them. The event records the emitting host's observation of
the transient pipeline position; it does not by itself prove that either side
was persisted or settled.

**Flows.** Operations that move value emit one flow event per affected amount,
with the matching `Actions` code:

| Operation                  | Event      | `action`           |
| -------------------------- | ---------- | ------------------ |
| deposit / depositPayable   | `Received` | `Actions.Deposit`  |
| withdraw                   | `Spent`    | `Actions.Withdraw` |
| burn                       | `Spent`    | `Actions.Burn`     |
| creditAccount              | `Received` | `Actions.Transfer` |
| debitAccount               | `Spent`    | `Actions.Transfer` |
| payout                     | `Spent` / `Received` | `Actions.Payout` |
| portPost                   | `Spent` / `Received` | `Actions.Post` |
| final pipeline budget      | `Received` | host posting action |
| provision (lock custody)   | `Locked`   | per operation      |
| custody release            | `Unlocked` | per operation      |

`Balance` and flow events are complementary, not redundant: flow events record
that value moved and why; `Balance` records the resulting total, which gives
indexers a checkpoint that survives missed deltas. An operation that both moves
value and changes a ledger total emits both.

Command native credit is trusted return data and produces no immediate ledger
event. It can fund later steps; the enclosing entrypoint emits through the host
posting hook only when it settles the final budget. Synchronous EVM execution
remains atomic: if settlement or a later pipeline step reverts, its event is
reverted as well.

**Asset gating.** Hosts that gate assets emit `AssetStatus` from their
`allowAsset`/`denyAsset` hooks (zero status means unsupported).

**Opaque assets.** Hosts that create or register opaque asset IDs emit `Asset`
with the canonical preimage used to resolve the asset. Indexers should treat
`asset` as the ledger key and can verify host-specific opaque IDs by checking
`asset == 0x00 || bytes31(hash(preimage))`. The first preimage byte is a
format/hash tag; `0x01` means keccak256. The rest of the payload is not yet
standardized.

**Invocations.** Top-level pipeline entrypoints emit `Rooted` once per
invocation with the acting account, deadline, and attached value. Detailed
effects are not duplicated into the invocation event; an indexer groups all
logs of the transaction to attribute effects to the invocation.

### Correlation Fields

`access` (on `Balance`) and `context` (on flow events) carry the node ID of the
causing endpoint — the innermost command, port, or guard whose semantic
performed the change — or zero when no endpoint context exists. `action` is a
code from `utils/Actions.sol`:

```txt
None 0, Transfer 1, Payout 2, Settle 3, Deposit 4, Withdraw 5, Fee 6,
Mint 7, Burn 8, Swap 9, Borrow 10, Repay 11, Liquidate 12, Refund 13, Post 14
```

Joins available to an indexer: `access`/`context` -> the endpoint repository
from discovery; transaction grouping -> the `Rooted` invocation and sibling
events; `(account, asset)` -> balance and flow history across all state events.

## Proposed Improvements

The discovery layer needs nothing. The proposals below close the remaining
gaps; none of them changes an existing event signature or topic, so all are
non-breaking per the changelog conventions.

### Proposed: Emitting Ledger Helpers

Add overloads to `Balances` that combine the mutation with the conforming
emission:

```solidity
function creditTo(bytes32 account, bytes32 asset, uint amount, uint access)
    internal returns (uint balance);
function debitFrom(bytes32 account, bytes32 asset, uint amount, uint access)
    internal returns (uint balance);
```

Each applies the raw mutation keyed by `asset` and emits
`Balance(account, asset, balance, +/-amount, access)`.
`Balances` already inherits `BalanceEvent` and the raw functions already return
the new total, so the change is additive; hosts with custom ledger schemes keep
using the raw overloads and emit on their own.

The motivation is correctness, not convenience: every host currently
hand-writes the same unpack-mutate-emit boilerplate, and the reference
template itself misattributes credits (its credit hook emits the debit
command's ID as `access`). A helper makes the conforming pattern the path of
least resistance. The cost is one log per mutation (~2k gas plus data words),
small next to the storage writes these operations already perform.

### Proposed: Make Correlation Semantics Normative

The `context` parameters are currently documented as "reserved for future use"
and `Balance.access` as "command ID or context identifier", which is too loose
to index against. Adopt the definition in [Correlation Fields](#correlation-fields)
as normative and update the event NatSpec accordingly.

## Considered And Rejected

These were evaluated and deliberately not proposed:

- **Per-invocation input/response events.** Input payloads are already in
  calldata and outputs in return data; logging them would roughly double the
  byte cost of every call. `Rooted` already marks invocations, and reverted
  calls emit no logs anyway, so such events cannot provide failure
  observability. The protocol's position stands: emit focused semantic events
  instead of mirroring complete input and output block streams into logs.
- **Unconditional library-forced flow emission for hook-driven commands.** Hosts
  route hooks internally (e.g. a payout hook that calls the credit hook), so
  unconditional emission at that layer would double-count or misattribute.
  Command credit remains in the pipeline budget for the same reason, avoiding
  producer-side events and repeated intermediate settlement.
- **Inventing an emitter for `Rooted` in the library.** `Rooted` belongs to host
  entrypoints the library does not own.
- **A dedicated event and command for every metadata type.** Entity metadata is
  carried by typed blocks inside `Annotation`, with the generic admin `annotate`
  command publishing later updates.

## Compatibility

Replacing `Labeled` and `Schema` with block-based `Annotation` changes the
discovery event surface and is breaking for indexers that consume the former
events. Consumers must decode annotation block streams and recognize `#label`
blocks for names and `#schema` blocks for block definitions.
