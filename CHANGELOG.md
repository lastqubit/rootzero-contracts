# Changelog

Until the protocol reaches integration-stable status, minor versions may include
breaking API changes. Breaking changes are called out explicitly.

## 1.1.0

### Breaking Changes

- Renamed local execution fields from `value` to `resources` in PIPE, CALL, and STEP schemas.
- Interprets EVM value as the low 128 bits of packed `resources`.
- Changed native value APIs and dispatch hooks to use `uint128` for actual EVM value.
- Replaced the relay-specific hook with shared `DispatchPayableHook`.
- `RelayPayable` now dispatches an encoded PIPE payload and settles leftover user command value.
