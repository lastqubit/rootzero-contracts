// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Keys } from "./Keys.sol";

/// @title Schemas
/// @notice Human-readable ABI-signature string constants for each block type.
/// These strings are the canonical source from which `Keys` constants are derived
/// and are used when emitting schema descriptors in command events.
library Schemas {
    string constant Amount = "amount(bytes32 asset, bytes32 meta, uint amount)";
    string constant Balance = "balance(bytes32 asset, bytes32 meta, uint amount)";
    string constant Custody = "custody(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant Minimum = "minimum(bytes32 asset, bytes32 meta, uint amount)";
    string constant Maximum = "maximum(bytes32 asset, bytes32 meta, uint amount)";
    string constant Break = "break()";
    string constant Route = "route(bytes data)";
    string constant RouteEmpty = "route()";
    string constant Quantity = "quantity(uint amount)";
    string constant Rate = "rate(uint value)";
    string constant Party = "party(bytes32 account)";
    string constant Recipient = "recipient(bytes32 account)";
    string constant Transaction = "tx(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)";
    string constant Step = "step(uint target, uint value, bytes request)";
    string constant Auth = "auth(uint cid, uint deadline, bytes proof)";
    string constant Asset = "asset(bytes32 asset, bytes32 meta)";
    string constant Node = "node(uint id)";
    string constant Listing = "listing(uint host, bytes32 asset, bytes32 meta)";
    string constant Funding = "funding(uint host, uint amount)";
    string constant Allocation = "allocation(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant Bounty = "bounty(uint amount, bytes32 relayer)";

    /// @notice Compose a route schema with one additional field.
    /// @param maybeRoute Existing route schema string, or empty string to start a fresh `route()`.
    /// @param a Schema string for the field to append.
    /// @return Composed schema string: `"route(...) & a"`.
    function route1(string memory maybeRoute, string memory a) internal pure returns (string memory) {
        return string.concat(bytes(maybeRoute).length == 0 ? RouteEmpty : maybeRoute, "&", a);
    }

    /// @notice Compose a route schema with two additional fields.
    /// @param maybeRoute Existing route schema string, or empty string to start a fresh `route()`.
    /// @param a Schema string for the first field to append.
    /// @param b Schema string for the second field to append.
    /// @return Composed schema string: `"route(...) & a & b"`.
    function route2(string memory maybeRoute, string memory a, string memory b) internal pure returns (string memory) {
        return string.concat(bytes(maybeRoute).length == 0 ? RouteEmpty : maybeRoute, "&", a, "&", b);
    }
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
//
// Schema DSL:
// - `;` separates top-level sibling blocks
// - `&` bundles adjacent blocks into one bundle block
// - bundled blocks preserve member order, so `a & b` differs from `b & a`
// - a bundle block's self payload is an embedded normal block stream of its bundled members
// - bundled members keep their ordinary block encoding, so dynamic blocks are allowed inside bundles
// - `->` separates request and response shapes, appears at most once, and is omitted when no output is modeled
// - top-level blocks of the same type should be grouped together
// - primary / driving blocks should appear before auxiliary blocks
// - `route(<fields...>)` is a reserved extensible schema form whose key is always `Keys.Route`
// - `&` compiles to a `Keys.Bundle` block whose self payload is the bundled member block stream
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
    /// @dev AUTH proof segment only: 20-byte signer + 65-byte signature = 85 bytes
    uint constant Proof = 85;
    /// @dev AUTH block: 8 header + 32 cid + 32 deadline + 85 proof = 157 bytes
    uint constant Auth = 157;
    /// @dev BALANCE block: 8 header + 32 asset + 32 meta + 32 amount = 104 bytes
    uint constant Balance = 104;
    /// @dev BOUNTY block: 8 header + 32 amount + 32 relayer = 72 bytes
    uint constant Bounty = 72;
    /// @dev CUSTODY block: 8 header + 32 host + 32 asset + 32 meta + 32 amount = 136 bytes
    uint constant Custody = 136;
    /// @dev TRANSACTION block: 8 header + 32 from + 32 to + 32 asset + 32 meta + 32 amount = 168 bytes
    uint constant Transaction = 168;
}

/// @notice Asset and amount pair; used for balance and amount blocks.
struct AssetAmount {
    /// @dev Asset identifier (encoding depends on asset type — see `Assets` library).
    bytes32 asset;
    /// @dev Asset metadata slot (e.g. token contract address or ERC-721 token ID context).
    bytes32 meta;
    /// @dev Token amount in the asset's native units.
    uint amount;
}

/// @notice Cross-host custody value; used for custody and allocation blocks.
struct HostAmount {
    /// @dev Host node ID that holds the custody position.
    uint host;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Token amount in the asset's native units.
    uint amount;
}

/// @notice User-scoped amount; associates an account with an asset amount.
struct UserAmount {
    /// @dev User account identifier.
    bytes32 account;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Token amount in the asset's native units.
    uint amount;
}

/// @notice Cross-host asset descriptor without an amount.
struct HostAsset {
    /// @dev Host node ID.
    uint host;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
}

/// @notice Transfer payload used across the pipeline and later consumed by settlement.
struct Tx {
    /// @dev Sender account identifier.
    bytes32 from;
    /// @dev Recipient account identifier.
    bytes32 to;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Transfer amount in the asset's native units.
    uint amount;
}
