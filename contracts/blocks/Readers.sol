// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ALLOCATION_KEY, AMOUNT_KEY, ASSET_KEY, AUTH_KEY, AUTH_PROOF_LEN, AUTH_TOTAL_LEN, BALANCE_KEY, BOUNTY_KEY, CUSTODY_KEY, BlockPairRef, BlockRef, DataRef, FUNDING_KEY, Listing, LISTING_KEY, MAXIMUM_KEY, MINIMUM_KEY, NODE_KEY, PARTY_KEY, QUANTITY_KEY, RATE_KEY, RECIPIENT_KEY, ROUTE_KEY, STEP_KEY, TX_KEY, AssetAmount, HostAmount, Tx} from "./Schema.sol";
import {InvalidBlock, MalformedBlocks, ZeroNode, ZeroRecipient} from "./Errors.sol";

using Blocks for BlockRef;

library Blocks {
    // ── infrastructure ────────────────────────────────────────────────────────

    function from(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        uint eod = source.length;
        if (i == eod) return BlockRef(bytes4(0), 0, 0, i);
        if (i > eod) revert MalformedBlocks();

        unchecked {
            ref.i = i + 12;
        }
        if (ref.i > eod) revert MalformedBlocks();
        ref.key = bytes4(source[i:i + 4]);
        ref.bound = ref.i + uint32(bytes4(source[i + 4:i + 8]));
        ref.end = ref.i + uint32(bytes4(source[i + 8:ref.i]));

        if (ref.bound > ref.end || ref.end > eod) revert MalformedBlocks();
    }

    function twoFrom(bytes calldata source, uint i) internal pure returns (BlockPairRef memory ref) {
        ref.a = from(source, i);
        i = ref.a.end;
        ref.b = from(source, i);
    }

    function childAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (BlockRef memory ref) {
        if (i < parent.bound || i >= parent.end) revert MalformedBlocks();
        ref = from(source, i);
        if (ref.end > parent.end) revert MalformedBlocks();
    }

    function count(bytes calldata source, uint i, bytes4 key) internal pure returns (uint count_, uint next) {
        next = i;
        while (next < source.length) {
            BlockRef memory ref = from(source, next);
            if (ref.key != key) break;
            unchecked {
                ++count_;
            }
            next = ref.end;
        }
    }

    function find(bytes calldata source, uint i, uint limit, bytes4 key) internal pure returns (BlockRef memory ref) {
        if (limit > source.length) revert MalformedBlocks();
        while (i < limit) {
            ref = from(source, i);
            if (ref.end > limit) revert MalformedBlocks();
            if (ref.key == key) return ref;
            i = ref.end;
        }

        return BlockRef(bytes4(0), limit, limit, limit);
    }

    function findChild(
        BlockRef memory parent,
        bytes calldata source,
        bytes4 key
    ) internal pure returns (BlockRef memory ref) {
        return find(source, parent.bound, parent.end, key);
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
        return create64(BOUNTY_KEY, bytes32(bounty), relayer);
    }

    function toBalanceBlock(bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return create96(BALANCE_KEY, asset, meta, bytes32(amount));
    }

    function toCustodyBlock(uint host, bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return create128(CUSTODY_KEY, bytes32(host), asset, meta, bytes32(amount));
    }

    function isBalance(BlockRef memory ref) internal pure returns (bool) {
        return ref.key == BALANCE_KEY;
    }

    function isCustody(BlockRef memory ref) internal pure returns (bool) {
        return ref.key == CUSTODY_KEY;
    }

    function resolveRecipient(
        bytes calldata source,
        uint i,
        uint limit,
        bytes32 backup
    ) internal pure returns (bytes32) {
        BlockRef memory ref = find(source, i, limit, RECIPIENT_KEY);
        bytes32 to = ref.key != 0 ? ref.unpackRecipient(source) : backup;
        if (to == 0) revert ZeroRecipient();
        return to;
    }

    function resolveNode(bytes calldata source, uint i, uint limit, uint backup) internal pure returns (uint) {
        BlockRef memory ref = find(source, i, limit, NODE_KEY);
        uint node = ref.key != 0 ? ref.unpackNode(source) : backup;
        if (node == 0) revert ZeroNode();
        return node;
    }

    function ensure(BlockRef memory ref, bytes4 key) internal pure {
        if (key == 0 || key != ref.key) revert InvalidBlock();
    }

    function ensure(BlockRef memory ref, bytes4 key, uint len) internal pure {
        if (key == 0 || key != ref.key || len != (ref.bound - ref.i)) revert InvalidBlock();
    }

    function ensure(BlockRef memory ref, bytes4 key, uint min, uint max) internal pure {
        uint len = ref.bound - ref.i;
        if (key == 0 || key != ref.key || len < min || (max != 0 && len > max)) revert InvalidBlock();
    }

    function ensure(BlockPairRef memory ref, bytes4 key, uint len) internal pure {
        ensure(ref.a, key, len);
        ensure(ref.b, key, len);
    }

    function ensure(BlockPairRef memory ref, bytes4 key, uint min, uint max) internal pure {
        ensure(ref.a, key, min, max);
        ensure(ref.b, key, min, max);
    }

    function verifyAuth(
        BlockRef memory ref,
        bytes calldata source,
        uint expectedCid
    ) internal pure returns (bytes32 hash, uint deadline, bytes calldata proof, uint next) {
        if (ref.end - ref.bound < AUTH_TOTAL_LEN) revert MalformedBlocks();
        uint cid;
        (cid, deadline, proof) = ref.innerAuthAt(source, ref.end - AUTH_TOTAL_LEN);
        if (cid != expectedCid) revert MalformedBlocks();
        hash = keccak256(source[ref.i - 12:ref.end - AUTH_PROOF_LEN]);
        next = ref.end;
    }

    function rebaseToDataRef(BlockRef memory ref, bytes calldata source) internal pure returns (DataRef memory out) {
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        out.key = ref.key;
        out.i = base + ref.i;
        out.bound = base + ref.bound;
        out.end = base + ref.end;
    }

    // ── *From ─────────────────────────────────────────────────────────────────

    function routeFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, ROUTE_KEY);
    }

    function nodeFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, NODE_KEY, 32);
    }

    function recipientFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, RECIPIENT_KEY, 32);
    }

    function partyFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, PARTY_KEY, 32);
    }

    function rateFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, RATE_KEY, 32);
    }

    function quantityFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, QUANTITY_KEY, 32);
    }

    function assetFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, ASSET_KEY, 64);
    }

    function fundingFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, FUNDING_KEY, 64);
    }

    function bountyFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, BOUNTY_KEY, 64);
    }

    function amountFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, AMOUNT_KEY, 96);
    }

    function amountTwoFrom(bytes calldata source, uint i) internal pure returns (BlockPairRef memory ref) {
        ref = twoFrom(source, i);
        ensure(ref, AMOUNT_KEY, 96);
    }

    function balanceFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, BALANCE_KEY, 96);
    }

    function balanceTwoFrom(bytes calldata source, uint i) internal pure returns (BlockPairRef memory ref) {
        ref = twoFrom(source, i);
        ensure(ref, BALANCE_KEY, 96);
    }

    function minimumFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, MINIMUM_KEY, 96);
    }

    function maximumFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, MAXIMUM_KEY, 96);
    }

    function listingFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, LISTING_KEY, 96);
    }

    function stepFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, STEP_KEY, 64, 0);
    }

    function authFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, AUTH_KEY, 149);
    }

    function custodyFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, CUSTODY_KEY, 128);
    }

    function custodyTwoFrom(bytes calldata source, uint i) internal pure returns (BlockPairRef memory ref) {
        ref = twoFrom(source, i);
        ensure(ref, CUSTODY_KEY, 128);
    }

    function allocationFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, ALLOCATION_KEY, 128);
    }

    function txFrom(bytes calldata source, uint i) internal pure returns (BlockRef memory ref) {
        ref = from(source, i);
        ensure(ref, TX_KEY, 160);
    }

    // ── inner* ────────────────────────────────────────────────────────────────

    function innerPair(BlockRef memory parent, bytes calldata source) internal pure returns (BlockPairRef memory ref) {
        ref.a = childAt(parent, source, parent.bound);
        ref.b = childAt(parent, source, ref.a.end);
    }

    function innerRoute(BlockRef memory parent, bytes calldata source) internal pure returns (bytes calldata data) {
        return unpackRoute(childAt(parent, source, parent.bound), source);
    }

    function innerNode(BlockRef memory parent, bytes calldata source) internal pure returns (uint id) {
        return unpackNode(childAt(parent, source, parent.bound), source);
    }

    function innerRecipient(BlockRef memory parent, bytes calldata source) internal pure returns (bytes32 account) {
        return unpackRecipient(childAt(parent, source, parent.bound), source);
    }

    function innerParty(BlockRef memory parent, bytes calldata source) internal pure returns (bytes32 account) {
        return unpackParty(childAt(parent, source, parent.bound), source);
    }

    function innerRate(BlockRef memory parent, bytes calldata source) internal pure returns (uint value) {
        return unpackRate(childAt(parent, source, parent.bound), source);
    }

    function innerQuantity(BlockRef memory parent, bytes calldata source) internal pure returns (uint amount) {
        return unpackQuantity(childAt(parent, source, parent.bound), source);
    }

    function innerAsset(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta) {
        return unpackAsset(childAt(parent, source, parent.bound), source);
    }

    function innerFunding(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (uint host, uint amount) {
        return unpackFunding(childAt(parent, source, parent.bound), source);
    }

    function innerBounty(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (uint amount, bytes32 relayer) {
        return unpackBounty(childAt(parent, source, parent.bound), source);
    }

    function innerAmount(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAmount(childAt(parent, source, parent.bound), source);
    }

    function innerBalance(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackBalance(childAt(parent, source, parent.bound), source);
    }

    function innerMinimum(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMinimum(childAt(parent, source, parent.bound), source);
    }

    function innerMaximum(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMaximum(childAt(parent, source, parent.bound), source);
    }

    function innerListing(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        return unpackListing(childAt(parent, source, parent.bound), source);
    }

    function innerStep(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (uint target, uint value, bytes calldata req) {
        return unpackStep(childAt(parent, source, parent.bound), source);
    }

    function innerAuth(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        return unpackAuth(childAt(parent, source, parent.bound), source);
    }

    function innerCustody(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (HostAmount memory value) {
        return toCustodyValue(childAt(parent, source, parent.bound), source);
    }

    function innerAllocation(
        BlockRef memory parent,
        bytes calldata source
    ) internal pure returns (HostAmount memory value) {
        return toAllocationValue(childAt(parent, source, parent.bound), source);
    }

    function innerTx(BlockRef memory parent, bytes calldata source) internal pure returns (Tx memory value) {
        return toTxValue(childAt(parent, source, parent.bound), source);
    }

    // ── inner*At ──────────────────────────────────────────────────────────────

    function innerPairAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (BlockPairRef memory ref) {
        ref.a = childAt(parent, source, i);
        ref.b = childAt(parent, source, ref.a.end);
    }

    function innerRouteAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (bytes calldata data) {
        return unpackRoute(childAt(parent, source, i), source);
    }

    function innerNodeAt(BlockRef memory parent, bytes calldata source, uint i) internal pure returns (uint id) {
        return unpackNode(childAt(parent, source, i), source);
    }

    function innerRecipientAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 account) {
        return unpackRecipient(childAt(parent, source, i), source);
    }

    function innerPartyAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 account) {
        return unpackParty(childAt(parent, source, i), source);
    }

    function innerRateAt(BlockRef memory parent, bytes calldata source, uint i) internal pure returns (uint value) {
        return unpackRate(childAt(parent, source, i), source);
    }

    function innerQuantityAt(BlockRef memory parent, bytes calldata source, uint i) internal pure returns (uint amount) {
        return unpackQuantity(childAt(parent, source, i), source);
    }

    function innerAssetAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta) {
        return unpackAsset(childAt(parent, source, i), source);
    }

    function innerFundingAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (uint host, uint amount) {
        return unpackFunding(childAt(parent, source, i), source);
    }

    function innerBountyAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (uint amount, bytes32 relayer) {
        return unpackBounty(childAt(parent, source, i), source);
    }

    function innerAmountAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAmount(childAt(parent, source, i), source);
    }

    function innerBalanceAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackBalance(childAt(parent, source, i), source);
    }

    function innerMinimumAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMinimum(childAt(parent, source, i), source);
    }

    function innerMaximumAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMaximum(childAt(parent, source, i), source);
    }

    function innerListingAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        return unpackListing(childAt(parent, source, i), source);
    }

    function innerStepAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (uint target, uint value, bytes calldata req) {
        return unpackStep(childAt(parent, source, i), source);
    }

    function innerAuthAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        return unpackAuth(childAt(parent, source, i), source);
    }

    function innerCustodyAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (HostAmount memory value) {
        return toCustodyValue(childAt(parent, source, i), source);
    }

    function innerAllocationAt(
        BlockRef memory parent,
        bytes calldata source,
        uint i
    ) internal pure returns (HostAmount memory value) {
        return toAllocationValue(childAt(parent, source, i), source);
    }

    function innerTxAt(BlockRef memory parent, bytes calldata source, uint i) internal pure returns (Tx memory value) {
        return toTxValue(childAt(parent, source, i), source);
    }

    // ── unpack*At ──────────────────────────────────────────────────────────────

    function unpackNodeAt(bytes calldata source, uint i) internal pure returns (uint id) {
        return unpackNode(from(source, i), source);
    }

    function unpackRecipientAt(bytes calldata source, uint i) internal pure returns (bytes32 account) {
        return unpackRecipient(from(source, i), source);
    }

    function unpackPartyAt(bytes calldata source, uint i) internal pure returns (bytes32 account) {
        return unpackParty(from(source, i), source);
    }

    function unpackRateAt(bytes calldata source, uint i) internal pure returns (uint value) {
        return unpackRate(from(source, i), source);
    }

    function unpackQuantityAt(bytes calldata source, uint i) internal pure returns (uint amount) {
        return unpackQuantity(from(source, i), source);
    }

    function unpackAssetAt(bytes calldata source, uint i) internal pure returns (bytes32 asset, bytes32 meta) {
        return unpackAsset(from(source, i), source);
    }

    function unpackFundingAt(bytes calldata source, uint i) internal pure returns (uint host, uint amount) {
        return unpackFunding(from(source, i), source);
    }

    function unpackBountyAt(bytes calldata source, uint i) internal pure returns (uint amount, bytes32 relayer) {
        return unpackBounty(from(source, i), source);
    }

    function unpackAmountAt(
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAmount(from(source, i), source);
    }

    function unpackBalanceAt(
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackBalance(from(source, i), source);
    }

    function unpackMinimumAt(
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMinimum(from(source, i), source);
    }

    function unpackMaximumAt(
        bytes calldata source,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMaximum(from(source, i), source);
    }

    function unpackListingAt(
        bytes calldata source,
        uint i
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        return unpackListing(from(source, i), source);
    }

    function unpackCustodyAt(bytes calldata source, uint i) internal pure returns (HostAmount memory value) {
        return toCustodyValue(from(source, i), source);
    }

    function unpackAllocationAt(bytes calldata source, uint i) internal pure returns (HostAmount memory value) {
        return toAllocationValue(from(source, i), source);
    }

    function unpackTxAt(bytes calldata source, uint i) internal pure returns (Tx memory value) {
        return toTxValue(from(source, i), source);
    }

    // ── unpack* ───────────────────────────────────────────────────────────────

    function unpackRoute(BlockRef memory ref, bytes calldata source) internal pure returns (bytes calldata data) {
        ensure(ref, ROUTE_KEY);
        return source[ref.i:ref.bound];
    }

    function unpackRouteUint(BlockRef memory ref, bytes calldata source) internal pure returns (uint) {
        ensure(ref, ROUTE_KEY, 32);
        return uint(bytes32(source[ref.i:ref.i + 32]));
    }

    function unpackRoute32(BlockRef memory ref, bytes calldata source) internal pure returns (bytes32) {
        ensure(ref, ROUTE_KEY, 32);
        return bytes32(source[ref.i:ref.i + 32]);
    }

    function unpackRoute64(BlockRef memory ref, bytes calldata source) internal pure returns (bytes32 a, bytes32 b) {
        ensure(ref, ROUTE_KEY, 64);
        a = bytes32(source[ref.i:ref.i + 32]);
        b = bytes32(source[ref.i + 32:ref.i + 64]);
    }

    function unpackRoute96(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        ensure(ref, ROUTE_KEY, 96);
        a = bytes32(source[ref.i:ref.i + 32]);
        b = bytes32(source[ref.i + 32:ref.i + 64]);
        c = bytes32(source[ref.i + 64:ref.i + 96]);
    }

    function unpackNode(BlockRef memory ref, bytes calldata source) internal pure returns (uint id) {
        ensure(ref, NODE_KEY, 32);
        return uint(bytes32(source[ref.i:ref.i + 32]));
    }

    function unpackRecipient(BlockRef memory ref, bytes calldata source) internal pure returns (bytes32 account) {
        ensure(ref, RECIPIENT_KEY, 32);
        return bytes32(source[ref.i:ref.i + 32]);
    }

    function unpackParty(BlockRef memory ref, bytes calldata source) internal pure returns (bytes32 account) {
        ensure(ref, PARTY_KEY, 32);
        return bytes32(source[ref.i:ref.i + 32]);
    }

    function unpackRate(BlockRef memory ref, bytes calldata source) internal pure returns (uint value) {
        ensure(ref, RATE_KEY, 32);
        return uint(bytes32(source[ref.i:ref.i + 32]));
    }

    function unpackQuantity(BlockRef memory ref, bytes calldata source) internal pure returns (uint amount) {
        ensure(ref, QUANTITY_KEY, 32);
        return uint(bytes32(source[ref.i:ref.i + 32]));
    }

    function unpackAsset(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta) {
        ensure(ref, ASSET_KEY, 64);
        return (bytes32(source[ref.i:ref.i + 32]), bytes32(source[ref.i + 32:ref.i + 64]));
    }

    function unpackFunding(BlockRef memory ref, bytes calldata source) internal pure returns (uint host, uint amount) {
        ensure(ref, FUNDING_KEY, 64);
        host = uint(bytes32(source[ref.i:ref.i + 32]));
        amount = uint(bytes32(source[ref.i + 32:ref.i + 64]));
    }

    function unpackBounty(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (uint amount, bytes32 relayer) {
        ensure(ref, BOUNTY_KEY, 64);
        amount = uint(bytes32(source[ref.i:ref.i + 32]));
        relayer = bytes32(source[ref.i + 32:ref.i + 64]);
    }

    function unpackAmount(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, AMOUNT_KEY, 96);
        return unpackAssetAmount(ref, source);
    }

    function unpackBalance(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, BALANCE_KEY, 96);
        return unpackAssetAmount(ref, source);
    }

    function unpackMinimum(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, MINIMUM_KEY, 96);
        return unpackAssetAmount(ref, source);
    }

    function unpackMaximum(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, MAXIMUM_KEY, 96);
        return unpackAssetAmount(ref, source);
    }

    function unpackListing(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        ensure(ref, LISTING_KEY, 96);
        host = uint(bytes32(source[ref.i:ref.i + 32]));
        asset = bytes32(source[ref.i + 32:ref.i + 64]);
        meta = bytes32(source[ref.i + 64:ref.i + 96]);
    }

    function unpackStep(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (uint target, uint value, bytes calldata req) {
        ensure(ref, STEP_KEY, 64, 0);
        target = uint(bytes32(source[ref.i:ref.i + 32]));
        value = uint(bytes32(source[ref.i + 32:ref.i + 64]));
        req = source[ref.i + 64:ref.bound];
    }

    function unpackAuth(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        ensure(ref, AUTH_KEY, 149);
        cid = uint(bytes32(source[ref.i:ref.i + 32]));
        deadline = uint(bytes32(source[ref.i + 32:ref.i + 64]));
        proof = source[ref.i + 64:ref.bound];
    }

    // ── to*Value ──────────────────────────────────────────────────────────────

    function toAmountValue(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (AssetAmount memory value) {
        ensure(ref, AMOUNT_KEY, 96);
        return toAssetAmount(ref, source);
    }

    function toBalanceValue(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (AssetAmount memory value) {
        ensure(ref, BALANCE_KEY, 96);
        return toAssetAmount(ref, source);
    }

    function toMinimumValue(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (AssetAmount memory value) {
        ensure(ref, MINIMUM_KEY, 96);
        return toAssetAmount(ref, source);
    }

    function toMaximumValue(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (AssetAmount memory value) {
        ensure(ref, MAXIMUM_KEY, 96);
        return toAssetAmount(ref, source);
    }

    function toListingValue(BlockRef memory ref, bytes calldata source) internal pure returns (Listing memory value) {
        ensure(ref, LISTING_KEY, 96);
        value.host = uint(bytes32(source[ref.i:ref.i + 32]));
        value.asset = bytes32(source[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(source[ref.i + 64:ref.i + 96]);
    }

    function toCustodyValue(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (HostAmount memory value) {
        ensure(ref, CUSTODY_KEY, 128);
        return toHostAmountValue(ref, source);
    }

    function toAllocationValue(
        BlockRef memory ref,
        bytes calldata source
    ) internal pure returns (HostAmount memory value) {
        ensure(ref, ALLOCATION_KEY, 128);
        return toHostAmountValue(ref, source);
    }

    function toTxValue(BlockRef memory ref, bytes calldata source) internal pure returns (Tx memory value) {
        ensure(ref, TX_KEY, 160);
        value.from = bytes32(source[ref.i:ref.i + 32]);
        value.to = bytes32(source[ref.i + 32:ref.i + 64]);
        value.asset = bytes32(source[ref.i + 64:ref.i + 96]);
        value.meta = bytes32(source[ref.i + 96:ref.i + 128]);
        value.amount = uint(bytes32(source[ref.i + 128:ref.i + 160]));
    }

    // ── private helpers ───────────────────────────────────────────────────────

    function unpackAssetAmount(
        BlockRef memory ref,
        bytes calldata source
    ) private pure returns (bytes32 asset, bytes32 meta, uint amount) {
        asset = bytes32(source[ref.i:ref.i + 32]);
        meta = bytes32(source[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(source[ref.i + 64:ref.i + 96]));
    }

    function toAssetAmount(BlockRef memory ref, bytes calldata source) private pure returns (AssetAmount memory value) {
        value.asset = bytes32(source[ref.i:ref.i + 32]);
        value.meta = bytes32(source[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(source[ref.i + 64:ref.i + 96]));
    }

    function toHostAmountValue(
        BlockRef memory ref,
        bytes calldata source
    ) private pure returns (HostAmount memory value) {
        value.host = uint(bytes32(source[ref.i:ref.i + 32]));
        value.asset = bytes32(source[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(source[ref.i + 64:ref.i + 96]);
        value.amount = uint(bytes32(source[ref.i + 96:ref.i + 128]));
    }
}
