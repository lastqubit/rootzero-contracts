// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Keys } from "./Keys.sol";

/// @title Schemas
/// @notice Human-readable ABI-signature string constants for each block type.
/// These strings are the canonical source from which `Keys` constants are derived
/// and are used when emitting schema descriptors in command events.
library Schemas {
    string constant Account = "account(bytes32 account)";
    string constant Position = "position(bytes32 account, bytes32 asset, bytes32 meta)";
    string constant PositionAt = "positionAt(uint host, bytes32 account, bytes32 asset, bytes32 meta)";
    string constant Entry = "entry(bytes32 account, bytes32 asset, bytes32 meta, uint amount)";
    string constant EntryAt = "entryAt(uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount)";
    string constant Asset = "asset(bytes32 asset, bytes32 meta)";
    string constant Amount = "amount(bytes32 asset, bytes32 meta, uint amount)";
    string constant Balance = "balance(bytes32 asset, bytes32 meta, uint amount)";
    string constant Minimum = "minimum(bytes32 asset, bytes32 meta, uint amount)";
    string constant Maximum = "maximum(bytes32 asset, bytes32 meta, uint amount)";
    string constant CustodyAt = "custodyAt(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant Transaction = "tx(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)";
    string constant Allocation = "allocation(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant Funding = "funding(uint host, uint amount)";
    string constant Call = "call(uint target, uint value, bytes data)";
    string constant Bounty = "bounty(uint amount, bytes32 relayer)";
    string constant Node = "node(uint id)";
    string constant Step = "step(uint target, uint value, bytes request)";
    string constant Quantity = "quantity(uint amount)";
    string constant Fee = "fee(uint amount)";
    string constant Rate = "rate(uint value)";
    string constant Bounds = "bounds(int min, int max)";
    string constant Auth = "auth(uint cid, uint deadline, bytes proof)";
    string constant Route = "route(bytes data)";
    string constant Item = "item(bytes data)";
    string constant Evm = "evm(bytes data)";
    string constant Query = "query(bytes data)";
    string constant Response = "response(bytes data)";
    string constant Break = "break()";
}

// Block stream:
// - encoding is [bytes4 key][bytes4 payloadLen][payload]
// - `payloadLen` covers only the block payload
// - payload layout is block-specific
//
// Extensible payloads:
// - self payload may be [head][dynamic tail]
// - head layout is implied by the block key
// - one dynamic field may consume the rest of self payload without its own length prefix
// - reserved extensible forms keep one fixed key while their declared field list remains descriptive schema metadata
// - chain-specific payload blocks are encoded using the local chain/runtime's native conventions
// - on EVM-family chains, `evm(<fields...>)` payloads use standard ABI tuple encoding via `abi.encode(...)`
//   and can be decoded with `abi.decode`
// - chain-specific payload blocks are request-only escape hatches and should never be used for pipeline state
// - prefer ordinary protocol blocks whenever possible; chain-specific payload blocks should be a last resort
//
// Schema DSL:
// - `;` separates top-level sibling blocks
// - `&` bundles adjacent blocks into one bundle block
// - `name = a & b` introduces a named bundle item
// - `bundle = a & b` introduces an anonymous child bundle item
// - postfix `[]` marks a repeated list in the simple suffix form, e.g. `asset(...)[]`
// - `name[] = a & b` introduces a named list whose repeated item is the bundled shape `a & b`
// - `list = a & b` introduces an anonymous list whose repeated item is the bundled shape `a & b`
// - empty entries are ignored, but structural markers are preserved after normalization
// - if `&` appears, the result remains a bundle even when only one non-empty child remains
// - after ignoring empty entries, repeated adjacent separators collapse while preserving bundle/list shape
// - bundled blocks preserve member order, so `a & b` differs from `b & a`
// - a bundle block's self payload is an embedded normal block stream of its bundled members
// - bundled members keep their ordinary block encoding, so dynamic blocks are allowed inside bundles
// - a list block's self payload is an embedded normal block stream representing the repeated items
// - top-level blocks of the same type should be grouped together
// - primary / driving blocks should appear before auxiliary blocks
// - `route(<fields...>)`, `item(<fields...>)`, `evm(<fields...>)`, `query(<fields...>)`,
//   and `response(<fields...>)` are reserved extensible schema forms whose keys are always
//   `Keys.Route`, `Keys.Item`, `Keys.Evm`, `Keys.Query`, and `Keys.Response` respectively
// - these extensible forms work like dynamic `bytes` blocks: they may carry arbitrary
//   payload bytes while keeping one fixed key per semantic block type
// - `evm(<fields...>)` differs from bundle/list payloads: its bytes are not an embedded block stream
// - `evm(uint foo, uint bar)` is a schema declaration only; on-chain the block key is still `Keys.Evm`
//   and the payload can be decoded from `bytes data` using the local runtime's native decoder
// - on EVM, `evm(bool flag)` occupies one full 32-byte ABI word, exactly like `abi.encode(flag)`
// - `&` compiles to a `Keys.Bundle` block whose self payload is the bundled member block stream
// - `[]` compiles to a `Keys.List` block whose self payload is the repeated item block stream
// - `asset(...)[]` means a list whose repeated item is the block `asset(...)`
// - `steps[] = asset(...) & account(...)` means a named list whose repeated item is the bundle
//   `asset(...) & account(...)`
// - `bundle = account(...) & evm(bytes routeData)` means an anonymous child bundle with those bundled members
// - `list = asset(...) & account(...)` means an anonymous child list whose repeated item is the
//   bundle `asset(...) & account(...)`
// - `"amount(...) &"` and `"& amount(...)"` both normalize to a bundle containing one `amount(...)` child
// - canonical blocks are `amount(...)` for request amounts, `balance(...)` for state balances,
//   `minimum(...)` for result floors, `maximum(...)` for spend ceilings, and `quantity(...)`
//   for plain scalar amounts
// - `auth(uint cid, uint deadline, bytes proof)` is a proof-separator block and must be emitted last
//
// Signed blocks:
// - an authenticated input segment ends with one trailing AUTH block
// - auth is typically grouped with the signed payload in one bundle, with AUTH as the final member
// - only the final AUTH is treated specially; earlier AUTH blocks remain ordinary signed bytes
// - the signed slice runs from the segment start through the AUTH head, excluding only AUTH proof bytes
// - `cid` binds the signature to one command; `deadline` acts as expiry and nonce
// - current helpers assume proof layout `[bytes20 signer][bytes65 sig]`

/// @title Sizes
/// @notice Total byte sizes for fixed-width block types, including the 8-byte header (4-byte key + 4-byte payloadLen).
library Sizes {
    /// @dev Shared block header size: 4-byte key + 4-byte payload length.
    uint constant Header = 8;
    /// @dev One fixed-width payload word.
    uint constant Word = 32;
    /// @dev 8 header + 32 payload = 40 bytes total.
    uint constant B32 = Header + Word;
    /// @dev 8 header + 64 payload = 72 bytes total.
    uint constant B64 = Header + 2 * Word;
    /// @dev 8 header + 96 payload = 104 bytes total.
    uint constant B96 = Header + 3 * Word;
    /// @dev 8 header + 128 payload = 136 bytes total.
    uint constant B128 = Header + 4 * Word;
    /// @dev 8 header + 160 payload = 168 bytes total.
    uint constant B160 = Header + 5 * Word;
    /// @dev AUTH proof segment only: 20-byte signer + 65-byte signature = 85 bytes
    uint constant Proof = 85;
    /// @dev AUTH block: 8 header + 32 cid + 32 deadline + 85 proof = 157 bytes
    uint constant Auth = B64 + Proof;
    /// @dev AMOUNT block: 8 header + 32 asset + 32 meta + 32 amount = 104 bytes
    uint constant Amount = B96;
    /// @dev BALANCE block: 8 header + 32 asset + 32 meta + 32 amount = 104 bytes
    uint constant Balance = B96;
    /// @dev BOUNDS block: 8 header + 32 min + 32 max = 72 bytes
    uint constant Bounds = B64;
    /// @dev FEE block: 8 header + 32 amount = 40 bytes
    uint constant Fee = B32;
    /// @dev BOUNTY block: 8 header + 32 amount + 32 relayer = 72 bytes
    uint constant Bounty = B64;
    /// @dev CUSTODY_AT block: 8 header + 32 host + 32 asset + 32 meta + 32 amount = 136 bytes
    uint constant CustodyAt = B128;
    /// @dev TRANSACTION block: 8 header + 32 from + 32 to + 32 asset + 32 meta + 32 amount = 168 bytes
    uint constant Transaction = B160;
}
