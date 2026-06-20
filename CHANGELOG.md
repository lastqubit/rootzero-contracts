# Changelog

Until the protocol reaches integration-stable status, minor versions may include
breaking API changes. Breaking changes are called out explicitly.

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
