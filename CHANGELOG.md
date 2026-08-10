# Changelog

Until the protocol reaches integration-stable status, minor versions may include
breaking API changes. Breaking changes are called out explicitly.

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
