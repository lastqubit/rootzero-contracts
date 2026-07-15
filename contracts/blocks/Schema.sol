// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Block stream:
// - encoding is [bytes4 key][bytes4 payloadLen][payload]
// - `payloadLen` is big-endian and covers only the block payload
// - payload layout is block-specific
//
// Schema:
// - block aliases are published separately from payload schemas
// - payload schemas are written as `{ fields }`
// - an empty schema string means the block has no structured payload
// - commas separate siblings at every level
// - braces define the current block payload body
// - command requests are a single run when the request schema is non-empty
// - command state is a single active state run without trailing globals
// - run items may repeat at top level for batching
// - `maybe #x` marks an optional block item
// - `many #x` emits one generic list block containing repeated `#x` items
// - endpoint descriptor lanes are `[key bytes4][item bytes4]`; normal keys widen to `[key][0]`
// - descriptor lanes for `many #x` use `[Keys.List][keyOfX]`; bare `[Keys.List][0]`
//   is incomplete discovery metadata and should be rejected by tooling
// - `portal` fields are routing identifiers, often destination host IDs
// - `resources` fields are chain-specific resource words. A portal adapter
//   interprets them for the destination runtime. EVM resources use the low
//   128 bits as native value.
// - dotted field names and aliases, e.g. `dst.portal` or `#bytes as dst.payload`,
//   are offchain projection metadata only and do not change runtime encoding
// - child blocks resolve by alias in the active schema context; unresolved aliases are invalid
// - schema strings describe the payload body only; the `Block` event carries the alias
// - items are encoded in declaration order
// - fixed fields are packed inline and any number of child blocks are embedded directly
// - child blocks may appear between fixed fields because each block carries its own length
// - `#bytes` is a reserved child block that stores raw bytes and has no body
// - `#string` is a reserved child block that stores UTF-8 string bytes and has no body
// - generic lists use the stable key derived from `#list`
// - standard keys are derived from block aliases, e.g. bytes4(keccak256("#amount"))
// - custom keys are opaque bytes4 tags and only need to be unique in their
//   active context; use `Schema(host, key, schema, name)` to publish their meaning
// - see `docs/Schema.md` for the full working spec
//
// Pipeline state:
// - command request and state streams are each a single run of blocks under the
//   current protocol convention; the block format may support other shapes in
//   future protocol surfaces
// - `balance(...)` and `custody(...)` are live, linear state in the active command pipeline
// - pipeline state belongs to the active account while the pipeline is executing
// - while a balance or custody is in-flight as pipeline state, it is not simultaneously persisted
//   in another ledger/store by this protocol
// - commands must preserve, transform, settle, or intentionally consume pipeline state
// - request blocks such as `amount(...)`, `allocation(...)`, and `allowance(...)`
//   express intent, constraints, or references
// - request and value/response blocks are not live state
//
// Signed blocks:
// - an authenticated input segment ends with one trailing AUTH block
// - only the final AUTH is treated specially; earlier AUTH blocks remain ordinary signed bytes
// - the signed slice runs from the segment start through the AUTH head, excluding only AUTH proof bytes
// - `cid` binds the signature to one command; `deadline` acts as expiry and nonce
// - current helpers assume proof layout `[bytes20 signer][bytes65 sig]`

/// @title Schemas
/// @notice Human-readable schema string constants for each block type.
/// These strings describe payload layout for discovery events and docs; block
/// aliases map to standard keys by convention. Custom blocks may use any unique
/// bytes4 key in their active context.
library Schemas {
    string constant Unit = "";
    string constant Node = "{ uint id }";
    string constant Account = "{ bytes32 account }";
    string constant Asset = "{ bytes32 asset }";
    string constant Amount = "{ bytes32 asset, uint amount }";
    string constant Balance = "{ bytes32 asset, uint amount }";
    string constant BalanceLimit = "{ bytes32 asset, uint min, uint max }";
    string constant Custody = "{ uint host, bytes32 asset, uint amount }";
    string constant CustodyLimit = "{ uint host, bytes32 asset, uint min, uint max }";
    string constant Allocation = "{ uint host, bytes32 asset, uint amount }";
    string constant Allowance = "{ uint host, bytes32 asset, uint amount }";
    string constant Transaction = "{ bytes32 from, bytes32 to, bytes32 asset, uint amount }";
    string constant Context = "{ bytes32 account, #bytes as state, #bytes as request }";
    string constant Recover = "{ uint handler, uint resources, bytes32 key, #bytes as witness }";
    string constant Call = "{ uint target, uint resources, #bytes as payload }";
    string constant Step = "{ uint target, uint resources, #bytes as request }";
    string constant Relay = "{ uint portal, uint resources, #bytes as request }";
    string constant Dispatch = "{ uint portal, uint resources, #bytes as payload }";
    string constant Bounty = "{ uint amount, bytes32 relayer }";
    string constant Fee = "{ uint amount }";
    string constant Auth = "{ uint cid, uint deadline, #bytes as proof }";
    string constant Label = "{ uint id, bytes32 namespace, #string as name }";
    string constant Schema = "{ bytes4 key, #string as body, bytes32 name }";
    string constant Bytes = "";
    string constant String = "";
    string constant List = "";
    string constant Evm = "";
}

/// @title Forms
/// @notice Reusable structural block schemas for core tuple shapes.
/// These describe payload form without assigning command or query semantics.
library Forms {
    string constant Status = "{ uint code }";
    string constant AssetAmount = "{ bytes32 asset, uint amount }";
    string constant AccountAsset = "{ bytes32 account, bytes32 asset }";
    string constant AccountAmount = "{ bytes32 account, bytes32 asset, uint amount }";
    string constant HostAmount = "{ uint host, bytes32 asset, uint amount }";
    string constant HostAccountAsset = "{ uint host, bytes32 account, bytes32 asset }";
    string constant HostAccountAmount = "{ uint host, bytes32 account, bytes32 asset, uint amount }";
}

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
    /// @dev AUTH block: 8 header + 32 cid + 32 deadline + nested BYTES block with 85-byte proof = 165 bytes
    uint constant Auth = B64 + Header + Proof;
    /// @dev STATUS block: 8 header + 32 status code = 40 bytes
    uint constant Status = B32;
    /// @dev AMOUNT block: 8 header + 32 asset + 32 amount = 72 bytes
    uint constant Amount = B64;
    /// @dev BALANCE block: 8 header + 32 asset + 32 amount = 72 bytes
    uint constant Balance = B64;
    /// @dev BALANCE_LIMIT block: 8 header + 32 asset + 32 min + 32 max = 104 bytes
    uint constant BalanceLimit = B96;
    /// @dev FEE block: 8 header + 32 amount = 40 bytes
    uint constant Fee = B32;
    /// @dev BOUNTY block: 8 header + 32 amount + 32 relayer = 72 bytes
    uint constant Bounty = B64;
    /// @dev ALLOCATION/CUSTODY block: 8 header + 32 host + 32 asset + 32 amount = 104 bytes
    uint constant HostAmount = B96;
    /// @dev CUSTODY_LIMIT block: 8 header + 32 host + 32 asset + 32 min + 32 max = 136 bytes
    uint constant CustodyLimit = B128;
    /// @dev TRANSACTION block: 8 header + 32 from + 32 to + 32 asset + 32 amount = 136 bytes
    uint constant Transaction = B128;
}
