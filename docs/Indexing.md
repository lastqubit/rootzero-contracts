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
event Command(uint indexed host, uint id, bytes32 shape, string request, bytes4 state, bytes4 output, bool funded)
event Admin(uint indexed host, uint id, bytes32 shape, string request, bytes4 state, bytes4 output, bool funded)
event Query(uint indexed host, uint id, bytes32 shape, string request, string response)
event Port(uint indexed host, uint id, bytes32 shape, string request, string response, bool funded)
event Guard(uint indexed host, uint id, string request)
```

- `shape` packs per-operation block counts as ASCII (`request:state:output` for
  commands, `request:response` for queries and ports).
- `request`, `response` are schema DSL strings per Schema.md, including dotted
  field paths and aliases for off-chain projection.
- `state`, `output` are the block keys for pipeline state in and out
  (`Keys.Empty`, `Keys.Any`, or a concrete key such as `Keys.Balance`).
- `funded` marks payable entrypoints.

Names arrive separately. Each standard mixin emits a canonical label at
construction, and the admin `label` command publishes mutable namespaced labels
later:

```txt
event Labeled(uint indexed id, bytes32 namespace, string name)
```

Labels are claims by the emitting contract: any contract may label any ID, so
indexers decide which emitters they trust per ID or namespace. Constructor
labels emitted by the host itself are trustworthy for that host's own
endpoints.

Host topology and access state are fully evented by the library:

```txt
event Introduction(uint indexed host, uint blocknum)
event Node(uint indexed host, uint node, bool active)
event Guardian(uint indexed host, bytes32 account, bool active)
```

`Introduction` fires on the commander when a new host introduces itself during
construction. Every node-trust change routes through `setNode` and every
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

1. Start from the chain's commander host (announced via `Chain`, below, or a
   known address). Replay its deployment logs: `EventAbi` gives the event ABIs,
   the discovery events give the endpoint catalog, `Labeled` gives names.
2. Follow `Introduction` events on the commander to enumerate hosts. The host
   ID embeds the host's address; the introducing host's commander is the
   contract that emitted the event, and its admin account derives from the
   commander address (`Accounts.toAdmin`).
3. For each host, repeat step 1 against its deployment logs, then replay
   `Node` and `Guardian` for live access sets.
4. Subscribe to the state events below for balances and flows.

The endpoint repository — commands, admin commands, queries, peers, and guards
with schemas, names, and access state — is fully reconstructible from logs
today. No changes are proposed to the discovery layer.

## State Events

The library defines a state-event vocabulary but does not emit it: all asset
and ledger mutation flows through virtual hooks (`deposit`, `withdraw`, `burn`,
`creditAccount`, `debitAccount`, `payout`, `provision`, `allowAsset`,
`denyAsset`, ...), and the hook implementation is the only layer that knows the
host's ledger policy - in particular the asset binding and the resulting
balance. Emission is therefore a host responsibility, governed by the
conventions below. The `create-rootzero` template (`rootzero-evm-commander`) is
the reference implementation of these conventions.

```txt
event Chain(uint indexed chain, bytes32 native, uint commander, bytes32 admin)
event Balance(bytes32 indexed account, bytes32 asset, uint balance, int change, uint access)
event Received(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)
event Spent(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)
event Locked(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)
event Unlocked(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)
event Asset(uint indexed host, bytes32 asset, bytes preimage)
event AssetStatus(uint indexed host, bytes32 asset, uint status)
event Position(bytes32 indexed account, bytes32 asset, uint value, uint32 action, uint context, uint queryId)
event Rooted(bytes32 indexed account, uint deadline, uint value)
```

### Host Conventions

A host that wants to be indexable from logs alone must follow these rules. A
host that omits them still works on-chain, but its ledger is invisible to
log-based tooling - there is no fallback channel, because command outputs are
return data and requests are calldata.

**Announcement.** A root (commander) host emits `Chain` once at construction
with the local chain ID, native asset, its own host ID, and its admin account,
and labels itself (e.g. `Labeled(host, "hosts", name)`). This closes the
cold-start problem: `commander`, `admin`, and `nativeAsset` are constructor
immutables that appear in no library event on the host itself. Child hosts need
no announcement - they are discovered through `Introduction` on their
commander.

**Balances.** Every ledger mutation emits `Balance` with the resulting total,
the signed change, and `access` set to the node ID of the endpoint that
performed the change. Hosts using the built-in `Balances` ledger key balances
directly by `(account, asset)`, so query results and events agree.

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
| portSettle                 | `Spent` / `Received` | `Actions.Settle` |
| provision (lock custody)   | `Locked`   | per operation      |
| custody release            | `Unlocked` | per operation      |

`Balance` and flow events are complementary, not redundant: flow events record
that value moved and why; `Balance` records the resulting total, which gives
indexers a checkpoint that survives missed deltas. An operation that both moves
value and changes a ledger total emits both.

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
causing endpoint — the innermost command, peer, or guard whose semantic
performed the change — or zero when no endpoint context exists. `action` is a
code from `utils/Actions.sol`:

```txt
None 0, Transfer 1, Payout 2, Settle 3, Deposit 4, Withdraw 5, Fee 6,
Mint 7, Burn 8, Swap 9, Borrow 10, Repay 11, Liquidate 12
```

Joins available to an indexer: `access`/`context` -> the endpoint repository
from discovery; transaction grouping -> the `Rooted` invocation and sibling
events; `(account, asset)` -> positions across all state events.

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

- **Per-invocation request/response events.** Request payloads are already in
  calldata and outputs in return data; logging them would roughly double the
  byte cost of every call. `Rooted` already marks invocations, and reverted
  calls emit no logs anyway, so such events cannot provide failure
  observability. The protocol's position stands: events carry *effects*, blocks
  carry *instructions*.
- **Library-forced flow emission inside command mixins.** Hosts route hooks
  internally (e.g. a payout hook that calls the credit hook), so unconditional
  emission at the mixin layer would double-count or misattribute. Emission
  belongs at the layer that decides ledger policy.
- **Inventing emitters for `Rooted` and `Position` in the library.** Both are
  host-policy vocabulary: `Rooted` belongs to host entrypoints the library does
  not own, and `Position` reporting depends on what the host considers a
  position.
- **Any change to the discovery events.** They are complete as deployed, and
  v1.2.0 already settled the naming model (`Labeled` + namespaces).

## Compatibility

Nothing in this document alters an event signature or topic. The proposed
helpers are additive Solidity; the correlation semantics and host conventions
are documentation that existing conforming hosts already satisfy. Under the
changelog conventions these ship as a non-breaking minor release.
