# Changelog

Until the protocol reaches integration-stable status, minor versions may include
breaking API changes. Breaking changes are called out explicitly.

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
