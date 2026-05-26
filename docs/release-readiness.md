# Release Readiness Analysis: `@rootzero/contracts` v0.9.5

## Context

This document analyzes whether the `rush-protocol` codebase is ready for a production release. The project is a **Solidity library** (`@rootzero/contracts`, GPL-3.0-only) that developers import to build decentralized hosts and command pipelines on the rootzero protocol. It is **not a deployed protocol with user funds** — it is an npm package of reusable abstract contracts. The "release" question therefore applies to:

1. **API stability**: Is the interface stable enough to build on without breaking changes?
2. **Library security**: Is the code safe enough that downstream implementations won't inherit design flaws?
3. **Documentation & auditability**: Is the library documented and audited to a production standard?

---

## What the Protocol Does

- **Block-stream wire format**: All inter-contract communication uses a binary block stream (`[bytes4 key][uint32 len][payload]`). Zero-copy parsing via a `Cur` cursor struct.
- **Node ID system**: 256-bit identifiers embedding type prefix, chain ID, selector, and address.
- **Command pipeline**: Stateless commands thread `bytes` state through STEP blocks. Final state must be empty.
- **Host model**: Abstract `Host` base contract wires together access control, commands, peers, and queries.
- **90 Solidity files** across `core/`, `commands/`, `peer/`, `queries/`, `blocks/`, `utils/`, `events/`.

---

## Strengths

### Security Fundamentals

| Area | Finding |
|------|---------|
| Solidity version | `^0.8.33` — built-in overflow/underflow protection everywhere |
| `unchecked` usage | Only in 3 places, all after explicit bounds checks (safe) |
| Access control | Three-tier: `onlyAdmin` (commander only), `onlyCommand` (trusted nodes), `onlyPeer` (trusted, non-commander) |
| ECDSA | Malleability threshold enforced; 65-byte sig enforced; v-value normalization; zero-signer rejection |
| Replay protection | (signer, uint192 nonce) pairs burned after first use in `Validator.sol:42` |
| Input validation | Cursor parsing has 150+ bounds checks; zero-amount rejection; zero-address rejection |
| Commander immutability | `commander` is `immutable` — cannot be re-assigned post-deploy |
| No `delegatecall` | None found — eliminates storage collision attacks |
| No `selfdestruct` | None found — no forced ETH injection attack surface |
| ETH calls | Uses low-level `call{}`, not deprecated `transfer`/`.send()` |
| Address zero checks | Commander, caller, ECDSA signer all reject `address(0)` |

### Test Coverage

- **19 test files, ~3,175 lines** of TypeScript tests using Hardhat + Mocha/Chai
- Covers: blocks, commands, admin ops, peer protocol, queries, ECDSA, access, validator, burn, discovery
- Custom Chai matchers for protocol-specific assertions
- Error path testing (`UnauthorizedCaller`, `InvalidNonce`, `InsufficientFunds`, etc.)

---

## Risks and Blockers

### BLOCKER — No Security Audit

**Status**: No `audit/`, `security/`, or findings documents exist anywhere in the repo.

This is the single largest release blocker. The protocol defines the security primitives (access control, ECDSA proofs, nonce management, balance accounting) that all downstream implementations will inherit. An independent audit is mandatory before downstream developers build financial applications on top of this library.

---

### BLOCKER — Active API Instability (Pre-1.0)

**Status**: Version `0.9.5`. Recent git history shows **breaking renames in the last 6 commits**:

- `849b5d7` — Rename relay blocks to pipe (breaking)
- `6c53347` — Refactor asset support query status (breaking)
- `0d3d924` — Simplify asset and position events (breaking)
- `66fc168` — Refactor asset boundary events (breaking)
- `d092b2a` — Refactor host discovery as introductions (breaking)

The protocol is in active refactoring. Releasing now locks in the current API for downstream consumers before the design has stabilized.

---

### BLOCKER — No CI/CD Pipeline

**Status**: Zero automated CI. Tests run locally only. No GitHub Actions, no lint, no static analysis (Slither/Mythril).

A library release without automated gates means broken builds can be published and static analysis findings go unchecked.

---

### HIGH — Centralized Admin Key, No Timelock

**Location**: `contracts/commands/admin/Execute.sol:26-39`

`ExecutePayable` is an admin escape hatch with no target restrictions:

```solidity
address addr = Ids.nodeAddr(target);
callAddr(addr, useValue(budget, value), data);  // No ensureTrusted(target) check
```

The admin (commander address) can call **any contract address** with any calldata and any ETH amount. This is intentional by design, but means:

- A single compromised commander key = full protocol compromise
- No delay between key compromise and asset drain
- No multi-sig or timelock protects high-value operations

**Affected admin commands**: `ExecutePayable`, `Authorize`, `Unauthorize`, `AllowAssets`, `DenyAssets`, `Allowance`, `Destroy` — all take effect instantly.

---

### HIGH — No Emergency Pause Mechanism

**Status**: No `pause()`/`unpause()` found in `Host`, `AccessControl`, or any core contract.

If a vulnerability is discovered post-deployment, there is no way to halt operations. This is a standard requirement for any DeFi-facing protocol.

---

### MEDIUM — No Reentrancy Guard on Payable Commands

**Locations**:

- `contracts/commands/Deposit.sol:77` — `depositPayable`
- `contracts/commands/Provision.sol:72` — `provisionPayable`
- `contracts/commands/Withdraw.sol:32` — `withdraw`

These commands invoke virtual hooks (`deposit(...)`, `withdraw(...)`) that downstream developers are expected to override. The base contracts provide no reentrancy guard. If a hook implementation makes an external call (e.g., ERC-20 `transferFrom`, ETH send), reentrancy is possible.

The `onlyCommand` modifier limits exposure to trusted callers — but the **hook implementations** written by library consumers are outside the library's control, and no documented warning exists in the base contracts.

---

### MEDIUM — `introduce()` Accepts Calls From Any Address

**Location**: `contracts/core/Host.sol:44`

```solidity
function introduce(uint peer, uint blocknum, uint16 version, string calldata namespace) external {
    emit Introduction(Ids.matchHost(peer, msg.sender), blocknum, version, namespace);
}
```

Any EOA or contract can call `introduce()` to emit an `Introduction` event. `Ids.matchHost` validates that the encoded `peer` address matches `msg.sender`, but this still allows arbitrary contracts to register themselves in off-chain indexers. The NatSpec correctly states "it does not authorize or trust the introduced host" — but indexers that treat `Introduction` events as authoritative discovery records could be manipulated.

---

### MEDIUM — No ETH Recovery Mechanism

**Location**: `contracts/core/Host.sol:49`

```solidity
receive() external payable {}
```

ETH sent directly to a host (not through the pipeline) accumulates with no admin-only sweep function. Stranded ETH cannot be recovered without using `ExecutePayable` with hand-crafted calldata.

---

### LOW — No Static Analysis Integration

No Slither, Mythril, or similar tool outputs are present. For a library that will be imported by financial applications, automated static analysis should be part of the release gate.

---

### LOW — Missing Explicit Events in Peer Operations

**Locations**: `contracts/peer/BalancePull.sol`, `contracts/peer/Settle.sol`

Peer balance pulls and settlements modify internal balances through hook overrides. If a downstream implementor's hook does not emit events, these state changes are invisible to off-chain monitoring. Protocol-level events should be emitted at the base contract layer, not delegated to hooks.

---

### LOW — Nonce Design Requires Consumer Guidance

**Location**: `contracts/core/Validator.sol:21`

```solidity
mapping(address account => mapping(uint192 key => uint64)) internal nonces;
if (nonces[account][nonce]++ != 0) revert InvalidNonce();
```

The 192-bit nonce key is opaque — the library does not document or enforce how callers derive nonces. If two independent callers choose the same `uint192` nonce for the same signer (e.g., both derive from a timestamp), one will silently revert. Required nonce derivation properties should be documented.

---

## Summary Verdict

| Category | Status | Comment |
|----------|--------|---------|
| Core security primitives | ✅ Strong | Overflow-safe, sound ECDSA, clear access control layering |
| Test breadth | ✅ Good | 3,175 lines covering happy paths and error cases |
| API stability | ❌ Blocker | Breaking renames in last 6 commits; pre-1.0 |
| Independent audit | ❌ Blocker | Hard requirement for any downstream financial use |
| CI/CD | ❌ Blocker | No automated gates |
| Admin key safety | ⚠️ Weak | Single key, no timelock, no emergency pause |
| Reentrancy safety for consumers | ⚠️ Undocumented | No guards or warnings in base hook contracts |
| Documentation | ⚠️ Partial | README + Schema.md are good; NatSpec is moderate; security docs are absent |

**Overall: NOT ready for a production release targeting financial applications.**

The library is in good shape for continued internal development and limited beta use. The three hard blockers before a stable release are: (1) independent security audit, (2) API stabilization to 1.0 with a defined stability guarantee, and (3) automated CI with static analysis.

---

## Recommended Pre-Release Checklist

1. **Freeze the API** — declare what is stable, adopt semver strictly, write a CHANGELOG
2. **Commission a security audit** — focus areas: access control model, ECDSA implementation, nonce design, pipeline reentrancy surface
3. **Add CI/CD** — GitHub Actions: compile + test on every push; Slither static analysis on PRs
4. **Add reentrancy documentation** — NatSpec warning on every `Hook` abstract contract that implementors must not make external calls without a reentrancy guard
5. **Add emergency pause** — `pause()`/`unpause()` mixin in `Host` with `onlyAdmin` gate
6. **Add ETH recovery** — admin-gated `sweep(address recipient, uint amount)` on `Host`
7. **Document the nonce derivation contract** — specify required uniqueness and freshness properties
8. **Consider timelock for admin actions** — especially `authorize`, `denyAssets`, and `destroy`

---

## Verification Commands

```bash
# Run full test suite
npm test

# Check for TODOs / FIXMEs
grep -r "TODO\|FIXME\|HACK" contracts/

# List all unchecked blocks
grep -rn "unchecked" contracts/

# Find all external call sites
grep -rn "\.call{" contracts/

# Check events are emitted in peer contracts
grep -rn "emit" contracts/peer/

# Confirm no delegatecall
grep -rn "delegatecall" contracts/

# Confirm no selfdestruct
grep -rn "selfdestruct" contracts/
```
