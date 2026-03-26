// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Keys } from "./Keys.sol";

library Schemas {
    string constant Amount = "amount(bytes32 asset, bytes32 meta, uint amount)";
    string constant Balance = "balance(bytes32 asset, bytes32 meta, uint amount)";
    string constant Custody = "custody(uint host, bytes32 asset, bytes32 meta, uint amount)";
    string constant Minimum = "minimum(bytes32 asset, bytes32 meta, uint amount)";
    string constant Maximum = "maximum(bytes32 asset, bytes32 meta, uint amount)";
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
}

// Block stream:
// - encoding is [bytes4 key][bytes4 selfLen][bytes4 totalLen][self payload][child blocks...]
// - `selfLen` covers only the block payload
// - `totalLen` covers payload plus child blocks
// - payload layout is block-specific
//
// Extensible payloads:
// - self payload may be [head][dynamic tail]
// - head layout is implied by the block key
// - one dynamic field may consume the rest of self payload without its own length prefix
// - child blocks, if any, are encoded as a normal nested block stream
//
// Schema DSL:
// - `;` separates top-level sibling blocks
// - `>` attaches child blocks to the preceding parent
// - repeated `>` adds more children to the same parent, not to the previous child
// - `->` separates request and response shapes, appears at most once, and is omitted when no output is modeled
// - top-level blocks of the same type should be grouped together
// - primary / driving blocks should appear before auxiliary blocks
// - `route(<fields...>)` is a reserved extensible schema form whose key is always `Keys.Route`
// - canonical blocks are `amount(...)` for request amounts, `balance(...)` for state balances,
//   `minimum(...)` for result floors, `maximum(...)` for spend ceilings, and `quantity(...)`
//   for plain scalar amounts
// - `auth(uint cid, uint deadline, bytes proof)` is a proof-separator child and must be emitted last
//
// Signed blocks:
// - a signed top-level block ends with one trailing AUTH child
// - only the final AUTH is treated specially; earlier AUTH blocks remain ordinary signed child bytes
// - the signed slice runs from the parent block start through the AUTH head, excluding only AUTH proof bytes
// - `cid` binds the signature to one command; `deadline` acts as expiry and nonce
// - current helpers assume proof layout `[bytes20 signer][bytes65 sig]`

uint constant AUTH_PROOF_LEN = 85;
uint constant AUTH_TOTAL_LEN = 161;

struct AssetAmount {
    bytes32 asset;
    bytes32 meta;
    uint amount;
}

struct HostAmount {
    uint host;
    bytes32 asset;
    bytes32 meta;
    uint amount;
}

struct UserAmount {
    bytes32 account;
    bytes32 asset;
    bytes32 meta;
    uint amount;
}

struct HostAsset {
    uint host;
    bytes32 asset;
    bytes32 meta;
}

struct Tx {
    bytes32 from;
    bytes32 to;
    bytes32 asset;
    bytes32 meta;
    uint amount;
}

struct Block {
    bytes4 key;
    uint i;
    uint bound;
    uint end;
    uint cursor;
}

struct BlockPair {
    Block a;
    Block b;
}

struct MemRef {
    bytes4 key;
    uint i;
    uint bound;
    uint end;
}

struct Writer {
    uint i;
    uint end;
    bytes dst;
}
