// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Block stream:
// - encoding is [bytes4 key][bytes4 payloadLen][payload]
// - `payloadLen` is big-endian and covers only the block payload
// - payload layout is block-specific
//
// Schema:
// - blocks are written as `#name { fields }`
// - a block without braces has no payload, e.g. `#unit`
// - commas separate siblings at every level
// - braces define parent-child boundaries
// - top-level item 0 is the prime item; later top-level items are globals
// - prime items may repeat at top level for batching
// - `maybe #x { ... }` marks an optional block item
// - `many #x { ... }` emits one generic list block containing repeated `#x` items
// - fixed fields are packed in declaration order
// - blocks have fixed fields followed by a dynamic child-block tail
// - child block tails are embedded directly, without an extra stream wrapper
// - `#bytes` is a reserved child block that stores raw bytes and has no body
// - generic `#data` uses the stable key derived from `#data`
// - generic lists use the stable key derived from `#list`
// - keys are derived from block names, e.g. bytes4(keccak256("#amount"))
// - see `docs/Schema.md` for the full working spec
//
// Pipeline state:
// - `balance(...)` and `custody(...)` are live, linear state in the active command pipeline
// - pipeline state belongs to the active account while the pipeline is executing
// - while a balance or custody is in-flight as pipeline state, it is not simultaneously persisted
//   in another ledger/store by this protocol
// - commands must preserve, transform, settle, or intentionally consume pipeline state
// - request blocks such as `amount(...)`, `allocation(...)`, `allowance(...)`, `payout(...)`,
//   `minimum(...)`, and `maximum(...)` express intent, constraints, or references
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
/// keys are derived only from block names.
library Schemas {
    string constant Unit = "#unit";
    string constant Node = "#node { uint id }";
    string constant Account = "#account { bytes32 account }";
    string constant Asset = "#asset { bytes32 asset, bytes32 meta }";
    string constant Balance = "#balance { bytes32 asset, bytes32 meta, uint amount }";
    string constant Amount = "#amount { bytes32 asset, bytes32 meta, uint amount }";
    string constant Minimum = "#minimum { bytes32 asset, bytes32 meta, uint amount }";
    string constant Maximum = "#maximum { bytes32 asset, bytes32 meta, uint amount }";
    string constant Custody = "#custody { uint host, bytes32 asset, bytes32 meta, uint amount }";
    string constant Payout = "#payout { bytes32 account, bytes32 asset, bytes32 meta, uint amount }";
    string constant Allocation = "#allocation { uint host, bytes32 asset, bytes32 meta, uint amount }";
    string constant Allowance = "#allowance { uint host, bytes32 asset, bytes32 meta, uint amount }";
    string constant Transaction = "#transaction { bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount }";
    string constant Context = "#context { bytes32 account, #bytes as state, #bytes as request }";
    string constant Relay = "#relay { uint target, uint value, #context { bytes32 account, #bytes as state, #bytes as request } }";
    string constant Call = "#call { uint target, uint value, #bytes as payload }";
    string constant Step = "#step { uint target, uint value, #bytes as request }";
    string constant Bounty = "#bounty { uint amount, bytes32 relayer }";
    string constant Fee = "#fee { uint amount }";
    string constant Auth = "#auth { uint cid, uint deadline, #bytes as proof }";
    string constant Bytes = "#bytes";
    string constant Data = "#data";
    string constant List = "#list";
    string constant Evm = "#evm";
}

/// @title Forms
/// @notice Reusable structural block schemas for core tuple shapes.
/// These describe payload form without assigning command or query semantics.
library Forms {
    string constant Status = "#status { bool ok }";
    string constant AssetAmount = "#assetAmount { bytes32 asset, bytes32 meta, uint amount }";
    string constant AccountAsset = "#accountAsset { bytes32 account, bytes32 asset, bytes32 meta }";
    string constant AccountAmount = "#accountAmount { bytes32 account, bytes32 asset, bytes32 meta, uint amount }";
    string constant HostAmount = "#hostAmount { uint host, bytes32 asset, bytes32 meta, uint amount }";
    string constant HostAccountAsset = "#hostAccountAsset { uint host, bytes32 account, bytes32 asset, bytes32 meta }";
    string constant HostAccountAmount =
        "#hostAccountAmount { uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount }";
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
    /// @dev STATUS block: 8 header + 1 bool byte = 9 bytes
    uint constant Status = Header + 1;
    /// @dev AMOUNT block: 8 header + 32 asset + 32 meta + 32 amount = 104 bytes
    uint constant Amount = B96;
    /// @dev BALANCE block: 8 header + 32 asset + 32 meta + 32 amount = 104 bytes
    uint constant Balance = B96;
    /// @dev FEE block: 8 header + 32 amount = 40 bytes
    uint constant Fee = B32;
    /// @dev BOUNTY block: 8 header + 32 amount + 32 relayer = 72 bytes
    uint constant Bounty = B64;
    /// @dev ALLOCATION/CUSTODY block: 8 header + 32 host + 32 asset + 32 meta + 32 amount = 136 bytes
    uint constant HostAmount = B128;
    /// @dev TRANSACTION block: 8 header + 32 from + 32 to + 32 asset + 32 meta + 32 amount = 168 bytes
    uint constant Transaction = B160;
}
