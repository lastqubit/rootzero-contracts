# Changelog

Until the protocol reaches integration-stable status, minor versions may include
breaking API changes. Breaking changes are called out explicitly.

## 1.23.0

### Breaking Changes

- Changed every command entrypoint from
  `(bytes32 account, bytes state, bytes input)` to one `bytes context` argument
  containing exactly one encoded `CONTEXT` block. Canonical command selectors
  now use `(bytes)`, so every command node ID changes. Existing command callers,
  cached IDs, and deployed host graphs are not compatible with this release.
- Added the acting account to `Execution`. `CommandBase.openCommand` and
  `AdminBase.openAdminCommand` now accept the encoded context and return only
  the initialized execution, and command implementations close with
  `closeCommand(exec)` instead of `close(exec, account)`.
- Removed the separate state argument from `RelayPayableHook.relay`. Relay
  implementations can obtain the complete validated state with
  `exec.rawState()` while the explicit account and nested relay input arguments
  remain unchanged.
- Consolidated `AllowAssetsPort` and `DenyAssetsPort` into
  `ports/Assets.sol`; update direct source imports to the new path.
- Renamed the peer `AllowancePort` and `portAllowance` selector to
  `RequestAllowancePort` and `portRequestAllowance`. The peer port now uses a
  distinct `RequestAllowanceHook.requestAllowance` hook; the admin `Allowance`
  command and its authoritative `AllowanceHook.allowance` hook are unchanged.
- Removed the `Commander` event declaration. Commander addresses and chain
  context are off-chain configuration; host, native-asset, and admin IDs are
  deterministic from that information.
- Prefixed every typed `Blocks` factory with `create`, including calldata-copy
  variants; for example, use `createBalance`, `createStepCopy`, `createBytes`,
  and `createString` instead of `balance`, `stepCopy`, `data`, and `text`.
- Changed the `max8`, `max16`, `max24`, `max32`, `max40`, `max64`, `max96`,
  `max128`, and `max160` bounds helpers to return their corresponding narrowed
  integer types instead of `uint`.

### Added

- Added `PositionedEvent`, which publishes asset and liability sides together
  with the semantic action that produced the observed position.
- Added `RequestAssetPort`, which passes trusted peers' batched asset and amount
  requests to a host hook for validation and fulfillment.
- Added `Executions.takeBlock`, which validates and consumes a block from a
  selected decoder lane and returns its complete calldata encoding.
- Added `Executions.rawState` and `Executions.rawInput` for retrieving complete
  validated calldata lanes independently of current cursor progress.
- Added `Blocks.createAmount` for constructing canonical `AMOUNT` blocks.

### Changed

- Command pipeline hops now construct `command(bytes)` calldata and the nested
  `CONTEXT` block directly in one allocation, copying memory state and calldata
  input into the final call buffer.
- Added memory `callPort`/`tryCallPort` helpers and calldata-copy
  `callPortCopy`/`tryCallPortCopy` counterparts, matching the block factory
  naming convention. Portal forwarding and recovery use the copy variants.

### Upgrade Compatibility

- Rebuild command IDs from the new `(bytes)` selectors, redeploy command hosts,
  and update pipeline builders and other callers to pass one encoded `CONTEXT`
  block. Do not mix 1.22 command IDs or callers with 1.23 deployments.
- Update custom commands to read the acting account from `exec.account`, use
  `openCommand(context, descriptor, batches)`, and return
  `closeCommand(exec)`.
- Update relay hook implementations to remove the state parameter and use
  `exec.rawState()` when the forwarded state is required.
- Update direct port imports, renamed request-allowance endpoints and hooks,
  typed `Blocks` factory calls, and any assignments that relied on `max*`
  returning `uint`.

## 1.22.0

### Breaking Changes

- Declared child blocks are now structurally present whenever their parent is
  non-empty. A child without a value uses its zero-payload block form instead
  of being omitted. The `maybe` modifier now hints that onchain code accepts
  that empty form; it no longer describes an absent item. Lists likewise keep
  their header and represent no items with an empty payload.
- Removed `Schemas.Unit`. Use the empty form of the block key that carries the
  relevant semantic meaning instead of a generic unit marker.
- Renamed `Decoders.take(cur, key)` to `takeBlock(cur, key)`. The `take` name is
  now used by raw cursor navigation and returns the absolute start of a
  bounds-checked byte range while advancing the cursor.
- Normalized standard schema bodies by removing their presentation-only outer
  braces, and renamed the standard node field from `id` to `node`. Published
  schema annotation bytes therefore change even though their wire layouts do
  not.

### Added

- Added empty-block inspection, conditional consumption, encoding, writing,
  and execution-output helpers across `Blocks`, `Decoders`, `Readers`,
  `Writers`, and `Executions`.
- Added `absolute`, `advance`, and raw `take` cursor helpers, plus `enter`
  overloads that advance over a validated fixed payload prefix in one cursor
  update.
- Added unnamed `schema` overloads for context-local specifications and an
  unnamed `Blocks.schema` factory overload.
- Added the offchain-only `at N` schema projection hint. Explicit positions are
  reserved first, then unannotated siblings fill the remaining positions in
  declaration order; wire encoding and onchain decoding remain unchanged.

### Changed

- Clarified that one optional pair of outer braces is presentation-only for all
  non-empty schema bodies, including custom top-level `many` schemas.
- Updated custom input examples to group fixed-width fields for direct calldata
  reads, demonstrate empty child blocks, and separate top-level and nested swap
  decoding.
- Excluded repository documentation and examples from the prepared npm package;
  the package continues to contain Solidity sources, the README, changelog, and
  license.

### Upgrade Compatibility

- Emit every declared child header in schema order. When a `maybe` child has no
  value, emit that child's key with a zero payload length and call
  `tryConsumeEmpty` before its strict semantic unpacker.
- Replace `Schemas.Unit` markers with an empty block carrying the key expected
  by the receiving schema.
- Replace `cur.take(key)` with `cur.takeBlock(key)`. Use `cur.take(amount)` only
  for raw fixed-width ranges.
- Indexers should accept braced and unbraced schema bodies, treat `maybe` as an
  empty-value hint, and apply `at N` only after decoding declaration-order wire
  data.

## 1.21.0

### Breaking Changes

- Repacked endpoint descriptors as `[state key:4][stride:1]`,
  `[input key:4][stride:1]`,
  `[output key:4][min:4][max:4][hint:3][stride:1]`, four reserved bytes,
  one transaction-count byte, and one flags byte. The input child-key field was
  removed; indexers and request builders must decode the new layout.
- Removed container metadata and the `many` and `keys` helpers from `Specs`.
  Top-level lists are now emitted custom schemas whose context-local key is the
  endpoint input key; nested lists continue to use the generic `#list` key.
- Replaced the `funded` and `admin` boolean parameters on command helpers and
  the `funded` boolean parameter on port helpers with a packed `uint8 flags`
  argument. Endpoint flags now live in the dedicated `Flags` library.
- Renamed the portal lifecycle events from `Undelivered` and `Recovered` to
  `Unresolved` and `Resolved`, and renamed `Portal.retry` to `Portal.resolve`.
  `Portal` now composes the node-access, runtime, and lifecycle-event
  capabilities; concrete implementations remain responsible for explicitly
  emitting lifecycle events.

### Added

- Added custom-spec overloads for `Decoders.list(cur, spec)` and
  `Executions.list(exec, spec, lane)` so custom-keyed top-level lists can use
  the same cursor model as generic nested lists.
- Added `Specs.lane` for canonical descriptor lane packing and exported
  `Flags` from the codec, command, and endpoint package entry points.

### Changed

- Updated schema and indexing documentation and the list example for the
  custom-keyed top-level list convention.

## 1.20.0

### Breaking Changes

- `Nodes.toCommand`, `toPort`, `toQuery`, and `toGuard` now take an endpoint
  name instead of a precomputed selector. The `Selectors` library was removed;
  endpoint node IDs now derive their canonical selectors internally.
- Renamed the memory-backed pipeline adapters from `InternalDebitAccount`,
  `InternalCreditAccount`, and `InternalSettle` to `DebitAccountInternal`,
  `CreditAccountInternal`, and `SettleInternal`.
- Replaced `RelayPayableHook.relayTo(portal, resources, payload, funds)` with
  `relay(portal, resources, account, state, input, funds)`. Relay commands now
  pass their semantic context fields to the host instead of encoding a
  `CONTEXT` payload before invoking the hook.
- `DispatchPayablePort` now uses the dedicated
  `DispatchPayableHook.dispatchTo(portal, resources, payload, funds)` hook
  instead of sharing `RelayPayableHook`.

### Added

- Added `RelayEvent`, with account, portal, resources, correlation key, and
  digest fields for recording outbound relay references.

### Changed

- Relay hooks retain state and nested relay input as calldata until an
  implementation chooses to encode or otherwise consume the destination
  context.

### Upgrade Compatibility

- Pass endpoint names directly to the `Nodes.to*` helpers and remove imports of
  `Selectors`.
- Update inherited internal adapter names and imports to the new postfix
  convention.
- Implement the structured `RelayPayableHook.relay` hook for relay commands and
  `DispatchPayableHook.dispatchTo` for opaque dispatch payloads. Hosts that
  support both surfaces must implement both hooks.

## 1.19.0

### Breaking Changes

- Renamed port endpoint contracts from the `Port*` prefix convention to the
  `*Port` postfix convention: `PortAllowAssets`, `PortAllowance`,
  `PortCreditAccount`, `PortDebitAccount`, `PortDenyAssets`,
  `PortDispatchPayable`, `PortPipePayable`, `PortPost`, and
  `PortRedeemBalance` are now `AllowAssetsPort`, `AllowancePort`,
  `CreditAccountPort`, `DebitAccountPort`, `DenyAssetsPort`,
  `DispatchPayablePort`, `PipePayablePort`, `PostPort`, and
  `RedeemBalancePort` respectively. Endpoint selectors are unchanged.
- Removed `Blocks.readUint`; cast `uint(Blocks.read32(abs))` when an unchecked
  absolute word read is required, or use the new cursor-consuming `next32`
  helpers while decoding.
- `Cursors.advance` and `Cursors.slice` now assume the documented packed-cursor
  invariant `i <= len` instead of pre-validating manually constructed cursor
  words. Invalid raw cursor words may now produce an arithmetic panic rather
  than `Cursors.OutOfBounds`.

### Added

- Added `enter` and `expectAbs` to `Decoders` and `Executions` for entering a
  parent payload, decoding its children in place, and proving exact final
  consumption.
- Added consuming `next1`, `next2`, `next4`, `next8`, `next16`, and `next32`
  helpers to `Decoders` and `Executions` for compact fixed-width schema fields.
- Added calldata-copy encoding across `Buffers`, `Blocks`, `Writers`, and
  `Executions`. In-place helpers use `copy*`, execution helpers use
  `outputCopy*`, and allocating block factories use the `*Copy` suffix.
- Added allocating factories for LIST, EVM, CONTEXT, and RECOVER blocks, plus
  memory and calldata factory pairs for dynamic leaf and composite blocks.

### Changed

- Block factories now allocate once and delegate to their canonical `write*`
  or `copy*` encoder instead of assembling nested intermediate byte arrays.
- Relay and dispatch paths preserve calldata slices until their destination
  requires memory, avoiding unnecessary explicit calldata-to-memory casts.
- `Settlement.settle` now implements its documented behavior by routing the
  liability leg through the virtual `repay` primitive before crediting the
  asset leg.
- Documented that restricting schema `bytesN` fields to power-of-two widths is
  under consideration; all widths from `bytes1` through `bytes32` remain valid.

### Upgrade Compatibility

- Update inherited port contract names and their imports to the new `*Port`
  names. No endpoint selector or wire-format migration is required.
- Replace `Blocks.readUint(abs)` with `uint(Blocks.read32(abs))`, or migrate
  sequential custom decoders to `enter`, `next*`, and `expectAbs`.
- Code that constructs packed cursors manually must establish `i <= len`
  before calling navigation helpers. Normal cursor constructors and composition
  helpers already preserve this invariant.
- `Settlement` subclasses that override `repay` will now have that override
  invoked by `settle`, matching the documented extension point.

## 1.18.0

### Added

- Added the non-funded `repay` and funded `repayPayable` commands. Both consume
  `Position` state, settle only its liability side, and return the released
  asset side as `Balance` state.
- Added the reusable non-funded `RepayHook` settlement primitive and the
  execution-funded `RepayPayableHook`.
- Added the opt-in `RevokeAsset` guardian endpoint, which accepts `Asset`
  entries and denies each asset through the existing `DenyAssetsHook`.

### Changed

- `Settlement.settle` now delegates its liability leg to the virtual `repay`
  primitive. The default behavior remains a nonzero `debitAccount` call, while
  derived settlement implementations can customize repayment in one place.
- Exported the repayment commands and hooks and the asset-revocation guard from
  their corresponding public barrels.

### Upgrade Compatibility

- Hosts inheriting `Settlement` retain the previous default settlement
  behavior. Hosts that already declare an internal
  `repay(bytes32,bytes32,uint)` function may need to mark it as an override or
  rename it when upgrading.

## 1.17.0

### Breaking Changes

- `executeDebitAccount`, `executeCreditAccount`, and `executeSettle` now require
  the pipeline step's `uint128 value` argument and reject nonzero value inside
  the internal adapter.
- `AllowanceHook` implementations must treat an amount of zero as revocation.

### Added

- Added the `HostAsset` structural block and complete codec support for
  host-scoped asset references.
- Added the opt-in `RevokeAllowance` guardian endpoint, which accepts
  `HostAsset` entries and revokes each allowance through `AllowanceHook`.
- Added the funded `settlePayable` command and `SettlePayableHook` for settlement
  implementations that require access to the command's native-value budget.

### Changed

- Completed the endpoint barrel with `CommandBase` and exported the new command,
  guard, hook, internal adapter, and structural type surfaces from their
  corresponding package barrels.

### Upgrade Compatibility

- Pipeline hosts using the internal debit, credit, or settle adapters must pass
  each step's assigned value into the adapter. Existing non-funded steps should
  continue to pass zero.

## 1.16.0

### Breaking Changes

- Removed the unused generic `Position` event and `PositionEvent` base contract.
- Renamed transaction handling from settlement to posting: the transaction
  helper is now `post(...)`, and `portSettle(bytes)` is now `portPost(bytes)`.
  The port selector and node ID change, and its action is now `Actions.Post`
  (`14`) instead of `Actions.Settle` (`3`). The `Settlement` convenience base
  implements both the transaction `PostHook` and position `SettleHook`.
- Removed `openInput` from `EndpointBase`. Port, query, and guard bases expose
  `openInput` through the input-only `InputEndpointBase`, while custom commands
  must pass both state and input through `openCommand`.
- Removed the wildcard `Specs.Any` state type. The stateful relay is now
  `relayBalancePayable` and accepts `BALANCE` state blocks; `relayPayable`
  explicitly accepts empty state.
- Renamed the numeric `Position` fields from `assets` and `liabilities` to
  `amount` and `debt`.
- Renamed `Budget.use` to `useResourceValue` and split execution spending into
  exact `useValue` and packed-resource `useResourceValue` helpers.
- Renamed `RoutePayableHook.route` to `RelayPayableHook.relayTo`. Recovery hooks
  are now `RecoverPayableHook` implementations that receive the complete
  resource word and mutable execution budget.

### Added

- Added the hostless `#position` state block for threading asset-liability pairs
  between pipeline commands.
- Added the `settle` command, the position `SettleHook`, and the transaction
  `PostHook`. The `Settlement` convenience base provides default implementations
  of both through the debit and credit account hooks.
- Added `relayBalancePayable` for relaying required `BALANCE` state while
  `relayPayable` now explicitly relays with empty state.
- Added memory-backed `InternalDebitAccount`, `InternalCreditAccount`, and
  `InternalSettle` adapters for hosts that execute canonical commands directly
  from their pipeline dispatcher.

### Changed

- Documented the command state-safety invariant: every command must handle the
  complete supplied state stream or revert, and commands with empty state lanes
  must reject non-empty state.
- Endpoint decoder opening now requires the complete supplied lane to be one
  homogeneous run of the descriptor's declared key; trailing block types are
  rejected instead of silently left outside the decoder cursor.
- Block runs and cursors now retain raw block counts only. Descriptor stride
  conversion and state/input group reconciliation happen once in execution
  opening rather than in `Blocks` or `Cursors`.
- Pipeline transaction streams are posted before the next step, and position
  state is settled separately through the scalar asset, amount, liability, and
  debt hook.
- Completed the public barrel exports for internal command adapters,
  input-only endpoint bases, access errors, and low-level utility helpers.

### Upgrade Compatibility

- Command and port selectors, block schemas, and hook signatures changed in
  this release. Deploy fresh hosts and update pipeline builders and peer
  integrations together.

## 1.15.0

### Breaking Changes

- Replaced the monolithic `AccessControl` base with the composable
  `CommanderAccess`, `AdminAccess`, `NodeAccess`, `GuardianAccess`,
  `CallerAccess`, and `TrustAccess` capabilities. `CommandBase` now requires a
  concrete caller policy and no longer inherits outbound `NodeCalls`.
- Split host composition into the commander-only `CommandHost`, the advanced
  `Host`, and the optional `Admins` and `Guardians` feature bundles. Commands
  that use trusted outbound calls must now inherit `NodeCalls` directly and
  compose a `TrustAccess` implementation.
- Removed the guardian account subtype. Guardians are now ordinary user
  accounts assigned a host-local role, so previously encoded guardian account
  IDs are not compatible.
- Replaced the `Labeled` and `Schema` discovery events and their dedicated admin
  commands with typed blocks in the generic `Annotation` event and the
  `annotate` admin command.
- Added the origin user account to `Introduction`, changing its event signature
  to `Introduction(uint indexed host, uint peer, bytes32 origin, uint blocknum)`.

### Added

- Added opt-in `Label`, `Schema`, and `Action` annotation mixins together with
  canonical `#label`, `#schema`, `#annotation`, and `#action` codec support.
- Added semantic action annotations to deposit, payable deposit, withdrawal,
  burn, payout, and port settlement endpoints.

### Changed

- Enabled the Solidity optimizer with 200 runs and pinned release testing to
  the Cancun EVM target, the minimum target supporting the codec's `MCOPY` use.
- Guardians can revoke node access but remain unable to grant it; admin
  commands continue to require both the immutable commander caller and its
  derived admin account.

### Upgrade Compatibility

- Existing deployments are not upgradeable and this release does not preserve
  storage layout or guardian mapping keys for proxy upgrades. Deploy fresh host
  contracts when adopting this version.

## 1.14.0

### Breaking Changes

- Replaced `CommandContext` and the separate payable value lifecycle with the
  unified `Execution` context. Endpoint and command implementations now open an
  execution directly from calldata, use its packed decoder and writer lanes,
  and finish through the shared `close` helpers.
- Reworked the block codec around absolute-position `Blocks` primitives,
  packed `Cursors`, cursor-backed `Decoders`, lazy `Buffers`, and thin
  `Writers`. Several low-level cursor and writer APIs were renamed or removed.
- Redefined block specs and endpoint descriptors. Specs now encode key, minimum,
  maximum, allocation hint, stride, and optional LIST container metadata;
  descriptors use normalized lane specs and include a transaction stride.
- Replaced the `Cursors.sol` package entry point with `Codec.sol`, added the
  command-authoring `Commands.sol` entry point, and reorganized exports across
  the package barrels.
- Endpoint selectors are now derived from endpoint names. The configured name
  must match the implementing function name, and descriptor values are
  represented as `uint` throughout.
- Removed the AUTH and BOUNTY codec blocks, the obsolete `Payable`/`Values`
  helpers, and superseded decoder, writer, schema, and descriptor overloads.

### Added

- Added packed output and transaction writer lanes to `Execution`, including
  semantic output helpers, queued credit/debit transactions, budget refunds,
  and direct transaction finalization.
- Added detachable `Budget` values for pipeline-style consumers, shared lane
  identifiers, spec-driven writer allocation, and optimized semantic block
  readers, writers, and composite unpackers.
- Added a transaction-output example, command and codec barrel import examples,
  and expanded coverage for packed cursors, buffers, descriptors, budgets,
  execution output, and command flows.

### Changed

- Standardized command, query, guard, and port implementations on the same
  execution open/close lifecycle and renamed request terminology to input.
- Expanded NatSpec across the new execution and codec APIs and refreshed the
  protocol, schema, indexing, and multi-chain documentation.

## 1.13.0

### Breaking Changes

- Replaced the virtual `Pipeline.settle(bytes transactions)` stream hook with
  decoded settlement through `Settlement`. Pipeline implementations now provide
  `debitAccount` and `creditAccount` hooks, while the pipeline decodes each
  returned TRANSACTION block and settles it before dispatching the next step.
- Moved `DebitAccountHook` and `CreditAccountHook` from their command modules to
  `core/Settlement.sol`. They remain available from the `Core.sol` and
  `Endpoints.sol` package entry points.

### Added

- Added the memory-backed `Reader` and `Readers` block-stream API with balance
  and transaction unpackers, bounds and block validation, and positive
  iteration through `more()`.
- Added the shared `Settlement` core mixin used by pipelines and `PortSettle` to
  debit transaction sources and credit destinations.

### Changed

- Unified pipeline and port transaction handling through `Settlement`,
  including zero-account handling and zero-amount no-op settlement.

## 1.12.0

### Breaking Changes

- Removed `Keys.Local` and replaced `EndpointBase.localSchema(...)` with the
  explicit `EndpointBase.schema(uint32 key, string body)` helper for
  context-local endpoint schemas.
- Changed `Introduction` to emit the receiving `host` and introduced `peer`:
  `Introduction(uint indexed host, uint peer, uint blocknum)`.
- Replaced `isDebitAccount`, `isCreditAccount`, `isAuthorize`, and
  `isUnauthorize` helper predicates with internal command ID fields:
  `debitAccountId`, `creditAccountId`, `authorizeId`, and `unauthorizeId`.

### Added

- Added the `EndpointBase.schema(...)` helper for publishing local endpoint
  schemas.
- Added the standard `#schema` block, `unpackSchema`, and an opt-in
  `publishSchema` admin command for emitting schema claims from `#schema`
  blocks.

### Changed

- Updated the schema DSL documentation to allow any number of child blocks in
  declaration order, including fixed fields before, after, or between child
  blocks.

## 1.11.0

### Breaking Changes

- Replaced the separate command, port, query, guard, and admin discovery events
  with the shared `Endpoint` event and a packed endpoint descriptor. Admin
  commands are now identified by the descriptor admin flag. Default lane groups
  remain encoded as zero and are interpreted as group size one when read; the
  final four descriptor bytes are reserved.
- Renamed the block discovery event to `Schema` and added a `name` field for
  alias-style schema references.
- Removed the generic `DATA` block type. Custom input blocks should define
  their own local keys and publish schemas explicitly when they need discovery.
- Removed the built-in admin `init` and `destroy` commands.
- Removed the built-in `Positions` query; custom position output should be
  modeled as a custom query.
- Changed `Cursors.list` to consume the LIST block and return a cursor scoped
  to its payload instead of returning the list's end offset.
- Renamed the `CommandContext.request` field to `input`. The tuple layout and
  command selectors are unchanged.

## 1.10.0

### Breaking Changes

- Moved `RecoverHook` from `Portal.sol` to `commands/Recover.sol`.
- Moved `RoutePayableHook` from `Portal.sol` to `commands/Relay.sol`.
- Renamed Portal helpers to `forward` / `retry`; hosts now explicitly bridge
  the `RecoverPayable` hook to Portal retry behavior.
- Renamed the generic `Resolved` event to `Recovered`.
- Portal no longer emits `Recovered` when retrying an undelivered witness.
- Renamed `Cursors.exit` to `ensureAt` and renamed its position argument to
  `pos`.
- Removed the redundant `next` return value from both `Decoders.init` overloads;
  callers should use the returned cursor's `len` as the run boundary.
- Changed `Cursors.list` to require the expected current cursor position as
  `pos` before entering the LIST block.

## 1.9.0

### Breaking Changes

- Renamed relay and dispatch routing fields from `chain` to `portal` across
  schemas, cursor helpers, dispatch hooks, and dispatch/route events.
- Replaced the context-specific `RecoverContextPayable` / `#contextRecovery`
  surface with generic `RecoverPayable` / `#recover` using byte witnesses.
- Renamed the `Dispatch` event correlation field from `ref` to `key`.
- Replaced `DispatchPayableHook.dispatch` with `RoutePayableHook.route` in the
  portal core layer.
- Added `status` to `Route(uint indexed host, uint portal, uint status)`
  so routes can be removed by emitting zero status.
- Added `Undelivered(uint indexed host, bytes32 key, bytes32 digest)` for portal
  messages that could not be delivered to their handler port.
- Added `Recovered(uint indexed host, bytes32 key)` as the
  matching event for resolved undelivered digests.
- Removed the generic `Commitments` core mixin and `Commitment` event in favor
  of domain-specific events such as `Undelivered` and `Recovered`.

## 1.8.0

### Breaking Changes

- Removed per-port `IPort*` interfaces. Port callers should use port node IDs,
  discovery metadata, and `PortCalls.callPort`.
- Removed unused standalone ABI encoder helpers: `encodePortCall`,
  `encodeGuardCall`, and `encodeQueryCall`.
- Reworked `NodeCalls` into a low-level node-call layer:
  - `callAddr` and `queryAddr` were removed.
  - `callTo` and `queryTo` were removed.
  - Raw node calls now use `rawCall`, `tryRawCall`, and `rawQuery`.

### Added

- Added `trustedCall`, `tryTrustedCall`, and `trustedQuery` as shared trusted
  wrappers over the raw node-call helpers.
- Added `CommandCalls.callCommand` and `PortCalls.callPort` for selector-based
  trusted calls to command and port nodes.

## 1.7.0

### Breaking Changes

- Renamed peer callable surfaces to ports:
  - `contracts/peer` moved to `contracts/ports`.
  - `PeerEvent` / `event Peer` became `PortEvent` / `event Port`.
  - `PeerBase`, `IPeer*`, and `Peer*` endpoint contracts became `PortBase`,
    `IPort*`, and `Port*`.
  - Peer endpoint functions and labels now use `port*` names, such as
    `portPipePayable`, `portDispatchPayable`, and `portSettle`.
  - Node helpers and layout tags now use `Port` terminology:
    `Nodes.toPort`, `Nodes.isPort`, `Nodes.port`, and
    `Nodes.portSelector`.
- Removed the generic `PortRecoverContextPayable`; recovery is now routed by
  the command-level `recoverContextPayable` to concrete ports such as
  `portPipePayable`.
- Renamed the `#contextRecovery` handler field from `target` to `port`.
- Changed port entrypoint calldata parameter naming to `data` to avoid
  clashing with nested context `request` fields.

### Added

- Added `RecoverContextPayable` and `#contextRecovery` for command-level
  recovery routing with a commitment key, resources, handler port, and context
  witness.
- Added `Dispatch(uint indexed host, uint chain, uint resources, bytes32 digest, bytes32 ref)`
  as the discovery/event surface for dispatch tracking.
- Added `ContextRecovery` schema/cursor support and context schema aliases for
  reusable nested block schemas.
- Added `Values.drain`, `Payable.openValue`, and `Payable.end` to make
  payable command budget lifecycles explicit.

## 1.6.0

### Added

- Added `AdminBase` as the shared base for admin commands and exported it from
  `Endpoints.sol`.
- Added `Cursors.read1` and `Cursors.read2` for unchecked byte-sized calldata
  reads.
- Added `NativeAsset` as a reusable base for helpers that need the local native
  asset ID without the full host runtime.
- Added `Escrows` as a keyed ledger for amounts reserved outside normal
  balances.
- Added `Commitment(uint indexed host, bytes32 key, bytes32 digest, uint status)`
  and the `Commitments` core mixin for digest commitments and witness/recovery
  flows.

## 1.5.0

### Breaking Changes

- Refactored account, asset, and node IDs around the shared convention that
  first byte `0x00` means opaque and nonzero means structured.
- Replaced the previous generic ID helpers with `Nodes` for structured host,
  chain, command, peer, query, and guard node IDs.
- Changed assets to single-word IDs: `bytes32 asset` is now the unique asset key
  without a separate metadata field or asset slot.
- `Payout` now passes destination accounts through to the hook unchanged; payout
  account policy is the hook implementation's responsibility.

### Added

- Added `Ids` as the shared helper library for opaque IDs, including
  `Ids.isOpaque`, `Ids.opaque`, `Ids.toKeccak`, and `Ids.matchKeccak`.
- Added opaque account, asset, and node helper wrappers in `Accounts`, `Assets`,
  and `Nodes`.
- Added `Asset(uint indexed host, bytes32 asset, bytes preimage)` for declaring
  opaque asset preimages.
- Documented opaque preimages as `[formatHash:1][payload...]`, where `0x01`
  means keccak256.

## 1.4.0

### Breaking Changes

- Replaced the `Chain` discovery event with `Commander(uint indexed host, uint chain, bytes32 native, bytes32 admin)`.
- Removed the `Transfer` flow event; account flows should be represented with `Spent` and `Received`.
- Renamed the indexed `Labeled` event parameter from `id` to `entity` in the published ABI string.

### Added

- Added `Route(uint indexed host, uint chain, uint context)` for generic cross-chain route discovery.
- Added `Actions.Refund` for unused payable command value returned through settlement hooks.

## 1.3.0

### Breaking Changes

- Simplified `Decoders.init` to parse a single run from the start of a calldata slice. Callers that previously passed an offset must slice first or use `Decoders.open(source, i)`.
- Tightened command, query, and peer request parsing around the single-run convention used by current protocol endpoints.

### Added

- Added `peerCreditTo` and `peerDebitFrom` peer endpoints for account-scoped `ACCOUNT_AMOUNT` batches.
- Added same-file `IPeer*` interfaces for every peer endpoint and exported them from `Endpoints.sol`.
- Added indexing documentation covering discovery, labels, access state, balance events, and flow-event conventions.

## 1.2.0

### Breaking Changes

- Removed human-readable names from Command, Admin, Peer, Query, Guard, and Chain discovery events.
- Added the Labeled event and default labels for commands, admin commands, peers, queries, guards, and examples.
- Added LABEL and STRING block schemas, plus cursor helpers for decoding labels supplied by callers.
- Added the admin label command for publishing mutable namespaced labels.
- Removed version and namespace fields from host Introduction events and host constructor introductions.

## 1.1.0

### Breaking Changes

- Renamed local execution fields from `value` to `resources` in PIPE, CALL, and STEP schemas.
- Interprets EVM value as the low 128 bits of packed `resources`.
- Changed native value APIs and dispatch hooks to use `uint128` for actual EVM value.
- Replaced the relay-specific hook with shared `DispatchPayableHook`.
- `RelayPayable` now dispatches an encoded PIPE payload and settles leftover user command value.
