// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AUTH_PROOF_LEN, AUTH_TOTAL_LEN, HostAsset, AssetAmount, HostAmount, Tx, Keys} from "./Schema.sol";
import {BALANCE_BLOCK_LEN, BOUNTY_BLOCK_LEN, CUSTODY_BLOCK_LEN, TX_BLOCK_LEN, Writer, Writers} from "./Writers.sol";

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

using Blocks for Block;

library Blocks {
    error MalformedBlocks();
    error InvalidBlock();
    error ZeroRecipient();
    error ZeroNode();
    error UnexpectedHost();
    error UnexpectedAsset();
    error UnexpectedMeta();

    // ── infrastructure ────────────────────────────────────────────────────────

    function at(uint i) internal pure returns (Block memory ref) {
        uint eod = msg.data.length;
        if (i == eod) return Block(bytes4(0), 0, 0, i, i);
        if (i > eod) revert MalformedBlocks();

        unchecked {
            ref.i = i + 12;
        }
        if (ref.i > eod) revert MalformedBlocks();
        ref.key = bytes4(msg.data[i:i + 4]);
        ref.bound = ref.i + uint32(bytes4(msg.data[i + 4:i + 8]));
        ref.end = ref.i + uint32(bytes4(msg.data[i + 8:ref.i]));

        if (ref.bound > ref.end || ref.end > eod) revert MalformedBlocks();
    }

    function from(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        uint base;
        uint eod = source.length;
        assembly ("memory-safe") {
            base := source.offset
        }

        if (i == eod) return Block(bytes4(0), 0, 0, base + i, i);
        if (i > eod) revert MalformedBlocks();

        uint start;
        unchecked {
            start = i + 12;
        }
        if (start > eod) revert MalformedBlocks();

        ref.key = bytes4(source[i:i + 4]);
        ref.i = base + start;
        ref.bound = ref.i + uint32(bytes4(source[i + 4:i + 8]));
        ref.end = ref.i + uint32(bytes4(source[i + 8:start]));
        ref.cursor = i + (ref.end - ref.i) + 12;

        uint eos = base + eod;
        if (ref.bound > ref.end || ref.end > eos) revert MalformedBlocks();
    }

    function twoFrom(bytes calldata source, uint i) internal pure returns (BlockPair memory ref) {
        ref.a = from(source, i);
        ref.b = from(source, ref.a.cursor);
    }

    function count(bytes calldata source, uint i, bytes4 key) internal pure returns (uint count_, uint next) {
        next = i;
        while (next < source.length) {
            Block memory ref = from(source, next);
            if (ref.key != key) break;
            unchecked {
                ++count_;
            }
            next = ref.cursor;
        }
    }

    function childAt(Block memory parent, uint i) internal pure returns (Block memory ref) {
        if (i < parent.bound || i >= parent.end) revert MalformedBlocks();
        ref = at(i);
        if (ref.end > parent.end) revert MalformedBlocks();
    }

    function findFrom(bytes calldata source, uint i, uint limit, bytes4 key) internal pure returns (Block memory ref) {
        if (limit > source.length) revert MalformedBlocks();
        while (i < limit) {
            ref = from(source, i);
            if (ref.cursor > limit) revert MalformedBlocks();
            if (ref.key == key) return ref;
            i = ref.cursor;
        }

        return Block(bytes4(0), limit, limit, limit, limit);
    }

    function findChild(Block memory parent, bytes4 key) internal pure returns (Block memory ref) {
        return findFrom(msg.data, parent.bound, parent.end, key);
    }

    function create32(bytes4 key, bytes32 value) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x20)), bytes4(uint32(0x20)), value);
    }

    function create64(bytes4 key, bytes32 a, bytes32 b) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x40)), bytes4(uint32(0x40)), a, b);
    }

    function create96(bytes4 key, bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x60)), bytes4(uint32(0x60)), a, b, c);
    }

    function create128(bytes4 key, bytes32 a, bytes32 b, bytes32 c, bytes32 d) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x80)), bytes4(uint32(0x80)), a, b, c, d);
    }

    function toBountyBlock(uint bounty, bytes32 relayer) internal pure returns (bytes memory) {
        return create64(Keys.Bounty, bytes32(bounty), relayer);
    }

    function toBalanceBlock(bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return create96(Keys.Balance, asset, meta, bytes32(amount));
    }

    function toCustodyBlock(uint host, bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return create128(Keys.Custody, bytes32(host), asset, meta, bytes32(amount));
    }

    function isBalance(Block memory ref) internal pure returns (bool) {
        return ref.key == Keys.Balance;
    }

    function isCustody(Block memory ref) internal pure returns (bool) {
        return ref.key == Keys.Custody;
    }

    function resolveRecipient(
        bytes calldata source,
        uint i,
        uint limit,
        bytes32 backup
    ) internal pure returns (bytes32) {
        Block memory ref = findFrom(source, i, limit, Keys.Recipient);
        bytes32 to = ref.key != 0 ? ref.unpackRecipient() : backup;
        if (to == 0) revert ZeroRecipient();
        return to;
    }

    function resolveNode(bytes calldata source, uint i, uint limit, uint backup) internal pure returns (uint) {
        Block memory ref = findFrom(source, i, limit, Keys.Node);
        uint node = ref.key != 0 ? ref.unpackNode() : backup;
        if (node == 0) revert ZeroNode();
        return node;
    }

    function verifyAuth(
        Block memory ref,
        uint expectedCid
    ) internal pure returns (bytes32 hash, uint deadline, bytes calldata proof) {
        if (ref.end - ref.bound < AUTH_TOTAL_LEN) revert MalformedBlocks();
        uint cid;
        (cid, deadline, proof) = innerAuthAt(ref, ref.end - AUTH_TOTAL_LEN);
        if (cid != expectedCid) revert MalformedBlocks();
        hash = keccak256(msg.data[ref.i - 12:ref.end - AUTH_PROOF_LEN]);
    }

    function ensure(Block memory ref, bytes4 key) internal pure {
        if (key == 0 || key != ref.key) revert InvalidBlock();
    }

    function ensure(Block memory ref, bytes4 key, uint len) internal pure {
        if (key == 0 || key != ref.key || len != (ref.bound - ref.i)) revert InvalidBlock();
    }

    function ensure(Block memory ref, bytes4 key, uint min, uint max) internal pure {
        uint len = ref.bound - ref.i;
        if (key == 0 || key != ref.key || len < min || (max != 0 && len > max)) revert InvalidBlock();
    }

    function ensure(BlockPair memory ref, bytes4 key, uint len) internal pure {
        ensure(ref.a, key, len);
        ensure(ref.b, key, len);
    }

    function ensure(BlockPair memory ref, bytes4 key, uint min, uint max) internal pure {
        ensure(ref.a, key, min, max);
        ensure(ref.b, key, min, max);
    }

    // ── *From ─────────────────────────────────────────────────────────────────

    function routeFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Route);
    }

    function nodeFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Node, 32);
    }

    function recipientFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Recipient, 32);
    }

    function partyFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Party, 32);
    }

    function rateFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Rate, 32);
    }

    function quantityFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Quantity, 32);
    }

    function assetFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Asset, 64);
    }

    function fundingFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Funding, 64);
    }

    function bountyFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Bounty, 64);
    }

    function amountFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Amount, 96);
    }

    function amountTwoFrom(bytes calldata source, uint i) internal pure returns (BlockPair memory ref) {
        ref = twoFrom(source, i);
        ensure(ref, Keys.Amount, 96);
    }

    function balanceFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Balance, 96);
    }

    function balanceTwoFrom(bytes calldata source, uint i) internal pure returns (BlockPair memory ref) {
        ref = twoFrom(source, i);
        ensure(ref, Keys.Balance, 96);
    }

    function minimumFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Minimum, 96);
    }

    function maximumFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Maximum, 96);
    }

    function listingFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Listing, 96);
    }

    function stepFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Step, 64, 0);
    }

    function authFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Auth, 149, 0);
    }

    function custodyFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Custody, 128);
    }

    function custodyTwoFrom(bytes calldata source, uint i) internal pure returns (BlockPair memory ref) {
        ref = twoFrom(source, i);
        ensure(ref, Keys.Custody, 128);
    }

    function allocationFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Allocation, 128);
    }

    function txFrom(bytes calldata source, uint i) internal pure returns (Block memory ref) {
        ref = from(source, i);
        ensure(ref, Keys.Transaction, 160);
    }

    // ── inner* ────────────────────────────────────────────────────────────────

    function innerPair(Block memory parent) internal pure returns (BlockPair memory ref) {
        ref.a = childAt(parent, parent.bound);
        ref.b = childAt(parent, ref.a.end);
    }

    function innerRoute(Block memory parent) internal pure returns (bytes calldata data) {
        return unpackRoute(childAt(parent, parent.bound));
    }

    function innerNode(Block memory parent) internal pure returns (uint id) {
        return unpackNode(childAt(parent, parent.bound));
    }

    function innerRecipient(Block memory parent) internal pure returns (bytes32 account) {
        return unpackRecipient(childAt(parent, parent.bound));
    }

    function innerParty(Block memory parent) internal pure returns (bytes32 account) {
        return unpackParty(childAt(parent, parent.bound));
    }

    function innerRate(Block memory parent) internal pure returns (uint value) {
        return unpackRate(childAt(parent, parent.bound));
    }

    function innerQuantity(Block memory parent) internal pure returns (uint amount) {
        return unpackQuantity(childAt(parent, parent.bound));
    }

    function innerAsset(Block memory parent) internal pure returns (bytes32 asset, bytes32 meta) {
        return unpackAsset(childAt(parent, parent.bound));
    }

    function innerFunding(Block memory parent) internal pure returns (uint host, uint amount) {
        return unpackFunding(childAt(parent, parent.bound));
    }

    function innerBounty(Block memory parent) internal pure returns (uint amount, bytes32 relayer) {
        return unpackBounty(childAt(parent, parent.bound));
    }

    function innerAmount(Block memory parent) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAmount(childAt(parent, parent.bound));
    }

    function innerAmountValue(Block memory parent) internal pure returns (AssetAmount memory) {
        return toAmountValue(childAt(parent, parent.bound));
    }

    function innerBalance(Block memory parent) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackBalance(childAt(parent, parent.bound));
    }

    function innerMinimum(Block memory parent) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMinimum(childAt(parent, parent.bound));
    }

    function innerMaximum(Block memory parent) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMaximum(childAt(parent, parent.bound));
    }

    function innerListing(Block memory parent) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        return unpackListing(childAt(parent, parent.bound));
    }

    function innerStep(Block memory parent) internal pure returns (uint target, uint value, bytes calldata req) {
        return unpackStep(childAt(parent, parent.bound));
    }

    function innerAuth(Block memory parent) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        return unpackAuth(childAt(parent, parent.bound));
    }

    function innerCustody(Block memory parent) internal pure returns (HostAmount memory value) {
        return toCustodyValue(childAt(parent, parent.bound));
    }

    function innerAllocation(Block memory parent) internal pure returns (HostAmount memory value) {
        return toAllocationValue(childAt(parent, parent.bound));
    }

    function innerTx(Block memory parent) internal pure returns (Tx memory value) {
        return toTxValue(childAt(parent, parent.bound));
    }

    // ── inner*At ──────────────────────────────────────────────────────────────

    function innerPairAt(Block memory parent, uint i) internal pure returns (BlockPair memory ref) {
        ref.a = childAt(parent, i);
        ref.b = childAt(parent, ref.a.end);
    }

    function innerRouteAt(Block memory parent, uint i) internal pure returns (bytes calldata data) {
        return unpackRoute(childAt(parent, i));
    }

    function innerNodeAt(Block memory parent, uint i) internal pure returns (uint id) {
        return unpackNode(childAt(parent, i));
    }

    function innerRecipientAt(Block memory parent, uint i) internal pure returns (bytes32 account) {
        return unpackRecipient(childAt(parent, i));
    }

    function innerPartyAt(Block memory parent, uint i) internal pure returns (bytes32 account) {
        return unpackParty(childAt(parent, i));
    }

    function innerRateAt(Block memory parent, uint i) internal pure returns (uint value) {
        return unpackRate(childAt(parent, i));
    }

    function innerQuantityAt(Block memory parent, uint i) internal pure returns (uint amount) {
        return unpackQuantity(childAt(parent, i));
    }

    function innerAssetAt(Block memory parent, uint i) internal pure returns (bytes32 asset, bytes32 meta) {
        return unpackAsset(childAt(parent, i));
    }

    function innerFundingAt(Block memory parent, uint i) internal pure returns (uint host, uint amount) {
        return unpackFunding(childAt(parent, i));
    }

    function innerBountyAt(Block memory parent, uint i) internal pure returns (uint amount, bytes32 relayer) {
        return unpackBounty(childAt(parent, i));
    }

    function innerAmountAt(
        Block memory parent,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAmount(childAt(parent, i));
    }

    function innerBalanceAt(
        Block memory parent,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackBalance(childAt(parent, i));
    }

    function innerMinimumAt(
        Block memory parent,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMinimum(childAt(parent, i));
    }

    function innerMaximumAt(
        Block memory parent,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMaximum(childAt(parent, i));
    }

    function innerListingAt(
        Block memory parent,
        uint i
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        return unpackListing(childAt(parent, i));
    }

    function innerStepAt(
        Block memory parent,
        uint i
    ) internal pure returns (uint target, uint value, bytes calldata req) {
        return unpackStep(childAt(parent, i));
    }

    function innerAuthAt(
        Block memory parent,
        uint i
    ) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        return unpackAuth(childAt(parent, i));
    }

    function innerCustodyAt(Block memory parent, uint i) internal pure returns (HostAmount memory value) {
        return toCustodyValue(childAt(parent, i));
    }

    function innerAllocationAt(Block memory parent, uint i) internal pure returns (HostAmount memory value) {
        return toAllocationValue(childAt(parent, i));
    }

    function innerTxAt(Block memory parent, uint i) internal pure returns (Tx memory value) {
        return toTxValue(childAt(parent, i));
    }

    function unpackNodeAt(bytes calldata source, uint i) internal pure returns (uint id) {
        return nodeFrom(source, i).unpackNode();
    }

    function unpackRecipientAt(bytes calldata source, uint i) internal pure returns (bytes32 account) {
        return recipientFrom(source, i).unpackRecipient();
    }

    function unpackPartyAt(bytes calldata source, uint i) internal pure returns (bytes32 account) {
        return partyFrom(source, i).unpackParty();
    }

    function unpackRateAt(bytes calldata source, uint i) internal pure returns (uint value) {
        return rateFrom(source, i).unpackRate();
    }

    function unpackQuantityAt(bytes calldata source, uint i) internal pure returns (uint amount) {
        return quantityFrom(source, i).unpackQuantity();
    }

    function unpackAssetAt(bytes calldata source, uint i) internal pure returns (bytes32 asset, bytes32 meta) {
        return assetFrom(source, i).unpackAsset();
    }

    function unpackFundingAt(bytes calldata source, uint i) internal pure returns (uint host, uint amount) {
        return fundingFrom(source, i).unpackFunding();
    }

    function unpackBountyAt(bytes calldata source, uint i) internal pure returns (uint amount, bytes32 relayer) {
        return bountyFrom(source, i).unpackBounty();
    }

    function unpackAmountAt(
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return amountFrom(source, i).unpackAmount();
    }

    function unpackBalanceAt(
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return balanceFrom(source, i).unpackBalance();
    }

    function unpackMinimumAt(
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return minimumFrom(source, i).unpackMinimum();
    }

    function unpackMaximumAt(
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return maximumFrom(source, i).unpackMaximum();
    }

    function unpackListingAt(
        bytes calldata source,
        uint i
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        return listingFrom(source, i).unpackListing();
    }

    function unpackCustodyAt(bytes calldata source, uint i) internal pure returns (HostAmount memory value) {
        return custodyFrom(source, i).toCustodyValue();
    }

    function unpackAllocationAt(bytes calldata source, uint i) internal pure returns (HostAmount memory value) {
        return allocationFrom(source, i).toAllocationValue();
    }

    function unpackTxAt(bytes calldata source, uint i) internal pure returns (Tx memory value) {
        return txFrom(source, i).toTxValue();
    }

    // ── unpack* ───────────────────────────────────────────────────────────────

    function unpackRoute(Block memory ref) internal pure returns (bytes calldata data) {
        ensure(ref, Keys.Route);
        return msg.data[ref.i:ref.bound];
    }

    function unpackRouteUint(Block memory ref) internal pure returns (uint) {
        ensure(ref, Keys.Route, 32);
        return uint(bytes32(msg.data[ref.i:ref.i + 32]));
    }

    function unpackRoute2Uint(Block memory ref) internal pure returns (uint a, uint b) {
        ensure(ref, Keys.Route, 96);
        a = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        b = uint(bytes32(msg.data[ref.i + 32:ref.i + 64]));
    }

    function unpackRoute3Uint(Block memory ref) internal pure returns (uint a, uint b, uint c) {
        ensure(ref, Keys.Route, 96);
        a = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        b = uint(bytes32(msg.data[ref.i + 32:ref.i + 64]));
        c = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackRoute32(Block memory ref) internal pure returns (bytes32) {
        ensure(ref, Keys.Route, 32);
        return bytes32(msg.data[ref.i:ref.i + 32]);
    }

    function unpackRoute64(Block memory ref) internal pure returns (bytes32 a, bytes32 b) {
        ensure(ref, Keys.Route, 64);
        a = bytes32(msg.data[ref.i:ref.i + 32]);
        b = bytes32(msg.data[ref.i + 32:ref.i + 64]);
    }

    function unpackRoute96(Block memory ref) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        ensure(ref, Keys.Route, 96);
        a = bytes32(msg.data[ref.i:ref.i + 32]);
        b = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        c = bytes32(msg.data[ref.i + 64:ref.i + 96]);
    }

    function unpackNode(Block memory ref) internal pure returns (uint id) {
        ensure(ref, Keys.Node, 32);
        return uint(bytes32(msg.data[ref.i:ref.i + 32]));
    }

    function unpackRecipient(Block memory ref) internal pure returns (bytes32 account) {
        ensure(ref, Keys.Recipient, 32);
        return bytes32(msg.data[ref.i:ref.i + 32]);
    }

    function unpackParty(Block memory ref) internal pure returns (bytes32 account) {
        ensure(ref, Keys.Party, 32);
        return bytes32(msg.data[ref.i:ref.i + 32]);
    }

    function unpackRate(Block memory ref) internal pure returns (uint value) {
        ensure(ref, Keys.Rate, 32);
        return uint(bytes32(msg.data[ref.i:ref.i + 32]));
    }

    function unpackQuantity(Block memory ref) internal pure returns (uint amount) {
        ensure(ref, Keys.Quantity, 32);
        return uint(bytes32(msg.data[ref.i:ref.i + 32]));
    }

    function unpackAsset(Block memory ref) internal pure returns (bytes32 asset, bytes32 meta) {
        ensure(ref, Keys.Asset, 64);
        return (bytes32(msg.data[ref.i:ref.i + 32]), bytes32(msg.data[ref.i + 32:ref.i + 64]));
    }

    function unpackFunding(Block memory ref) internal pure returns (uint host, uint amount) {
        ensure(ref, Keys.Funding, 64);
        host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        amount = uint(bytes32(msg.data[ref.i + 32:ref.i + 64]));
    }

    function unpackBounty(Block memory ref) internal pure returns (uint amount, bytes32 relayer) {
        ensure(ref, Keys.Bounty, 64);
        amount = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        relayer = bytes32(msg.data[ref.i + 32:ref.i + 64]);
    }

    function unpackAmount(Block memory ref) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, Keys.Amount, 96);
        asset = bytes32(msg.data[ref.i:ref.i + 32]);
        meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackBalance(Block memory ref) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, Keys.Balance, 96);
        asset = bytes32(msg.data[ref.i:ref.i + 32]);
        meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackMinimum(Block memory ref) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, Keys.Minimum, 96);
        asset = bytes32(msg.data[ref.i:ref.i + 32]);
        meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackMaximum(Block memory ref) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, Keys.Maximum, 96);
        asset = bytes32(msg.data[ref.i:ref.i + 32]);
        meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackListing(Block memory ref) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        ensure(ref, Keys.Listing, 96);
        host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
    }

    function unpackStep(Block memory ref) internal pure returns (uint target, uint value, bytes calldata req) {
        ensure(ref, Keys.Step, 64, 0);
        target = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        value = uint(bytes32(msg.data[ref.i + 32:ref.i + 64]));
        req = msg.data[ref.i + 64:ref.bound];
    }

    function unpackAuth(Block memory ref) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        ensure(ref, Keys.Auth, 149);
        cid = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        deadline = uint(bytes32(msg.data[ref.i + 32:ref.i + 64]));
        proof = msg.data[ref.i + 64:ref.bound];
    }

    // ── expect* ───────────────────────────────────────────────────────────────

    function expectAmount(Block memory ref, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        ensure(ref, Keys.Amount, 96);
        if (bytes32(msg.data[ref.i:ref.i + 32]) != asset) revert UnexpectedAsset();
        if (bytes32(msg.data[ref.i + 32:ref.i + 64]) != meta) revert UnexpectedMeta();
        return uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function expectBalance(Block memory ref, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        ensure(ref, Keys.Balance, 96);
        if (bytes32(msg.data[ref.i:ref.i + 32]) != asset) revert UnexpectedAsset();
        if (bytes32(msg.data[ref.i + 32:ref.i + 64]) != meta) revert UnexpectedMeta();
        return uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function expectMinimum(Block memory ref, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        ensure(ref, Keys.Minimum, 96);
        if (bytes32(msg.data[ref.i:ref.i + 32]) != asset) revert UnexpectedAsset();
        if (bytes32(msg.data[ref.i + 32:ref.i + 64]) != meta) revert UnexpectedMeta();
        return uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function expectMaximum(Block memory ref, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        ensure(ref, Keys.Maximum, 96);
        if (bytes32(msg.data[ref.i:ref.i + 32]) != asset) revert UnexpectedAsset();
        if (bytes32(msg.data[ref.i + 32:ref.i + 64]) != meta) revert UnexpectedMeta();
        return uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function expectCustody(Block memory ref, uint host) internal pure returns (AssetAmount memory value) {
        ensure(ref, Keys.Custody, 128);
        if (uint(bytes32(msg.data[ref.i:ref.i + 32])) != host) revert UnexpectedHost();
        value.asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
        value.amount = uint(bytes32(msg.data[ref.i + 96:ref.i + 128]));
    }

    // ── to*Value ──────────────────────────────────────────────────────────────

    function toAmountValue(Block memory ref) internal pure returns (AssetAmount memory value) {
        ensure(ref, Keys.Amount, 96);
        value.asset = bytes32(msg.data[ref.i:ref.i + 32]);
        value.meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function toBalanceValue(Block memory ref) internal pure returns (AssetAmount memory value) {
        ensure(ref, Keys.Balance, 96);
        value.asset = bytes32(msg.data[ref.i:ref.i + 32]);
        value.meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function toMinimumValue(Block memory ref) internal pure returns (AssetAmount memory value) {
        ensure(ref, Keys.Minimum, 96);
        value.asset = bytes32(msg.data[ref.i:ref.i + 32]);
        value.meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function toMaximumValue(Block memory ref) internal pure returns (AssetAmount memory value) {
        ensure(ref, Keys.Maximum, 96);
        value.asset = bytes32(msg.data[ref.i:ref.i + 32]);
        value.meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function toListingValue(Block memory ref) internal pure returns (HostAsset memory value) {
        ensure(ref, Keys.Listing, 96);
        value.host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        value.asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
    }

    function toCustodyValue(Block memory ref) internal pure returns (HostAmount memory value) {
        ensure(ref, Keys.Custody, 128);
        value.host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        value.asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
        value.amount = uint(bytes32(msg.data[ref.i + 96:ref.i + 128]));
    }

    function toAllocationValue(Block memory ref) internal pure returns (HostAmount memory value) {
        ensure(ref, Keys.Allocation, 128);
        value.host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        value.asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
        value.amount = uint(bytes32(msg.data[ref.i + 96:ref.i + 128]));
    }

    function toTxValue(Block memory ref) internal pure returns (Tx memory value) {
        ensure(ref, Keys.Transaction, 160);
        value.from = bytes32(msg.data[ref.i:ref.i + 32]);
        value.to = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.asset = bytes32(msg.data[ref.i + 64:ref.i + 96]);
        value.meta = bytes32(msg.data[ref.i + 96:ref.i + 128]);
        value.amount = uint(bytes32(msg.data[ref.i + 128:ref.i + 160]));
    }
}
