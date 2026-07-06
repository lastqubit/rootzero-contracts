# Changelog

Until the protocol reaches integration-stable status, minor versions may include
breaking API changes. Breaking changes are called out explicitly.

## Unreleased

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
- Removed the redundant `next` return value from both `Cursors.init` overloads;
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
- Added `Values.drain`, `Payable.openValue`, and `Payable.closeValue` to make
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

- Simplified `Cursors.init` to parse a single run from the start of a calldata slice. Callers that previously passed an offset must slice first or use `Cursors.open(source, i)`.
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
