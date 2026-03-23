// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ALLOCATION_KEY, AMOUNT_KEY, ASSET_KEY, AUTH_KEY, BALANCE_KEY, BOUNTY_KEY, CUSTODY_KEY, DataPairRef, DataRef, FUNDING_KEY, Listing, LISTING_KEY, MAXIMUM_KEY, MINIMUM_KEY, NODE_KEY, PARTY_KEY, RATE_KEY, RECIPIENT_KEY, ROUTE_KEY, STEP_KEY, TX_KEY, AssetAmount, HostAmount, Tx} from "./Schema.sol";
import {InvalidBlock, MalformedBlocks} from "./Errors.sol";

using Data for DataRef;

library Data {
    // ── infrastructure ────────────────────────────────────────────────────────

    function at(uint i) internal pure returns (DataRef memory ref) {
        uint eod = msg.data.length;
        if (i == eod) return DataRef(bytes4(0), 0, 0, i);
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

    function from(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        uint base;
        uint eod = source.length;
        assembly ("memory-safe") {
            base := source.offset
        }

        if (i == eod) return (DataRef(bytes4(0), 0, 0, base + i), i);
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

        uint eos = base + eod;
        if (ref.bound > ref.end || ref.end > eos) revert MalformedBlocks();
        next = i + (ref.end - ref.i) + 12;
    }

    function twoFrom(bytes calldata source, uint i) internal pure returns (DataPairRef memory ref, uint next) {
        (ref.a, i) = from(source, i);
        (ref.b, next) = from(source, i);
    }

    function childAt(DataRef memory parent, uint i) internal pure returns (DataRef memory ref) {
        if (i < parent.bound || i >= parent.end) revert MalformedBlocks();
        ref = at(i);
        if (ref.end > parent.end) revert MalformedBlocks();
    }

    function findFrom(
        bytes calldata source,
        uint i,
        uint limit,
        bytes4 key
    ) internal pure returns (DataRef memory ref) {
        if (limit > source.length) revert MalformedBlocks();
        while (i < limit) {
            uint next;
            (ref, next) = from(source, i);
            if (next > limit) revert MalformedBlocks();
            if (ref.key == key) return ref;
            i = next;
        }

        return DataRef(bytes4(0), limit, limit, limit);
    }

    function findChild(DataRef memory parent, bytes4 key) internal pure returns (DataRef memory ref) {
        return findFrom(msg.data, parent.bound, parent.end, key);
    }

    function ensure(DataRef memory ref, bytes4 key) internal pure {
        if (key == 0 || key != ref.key) revert InvalidBlock();
    }

    function ensure(DataRef memory ref, bytes4 key, uint len) internal pure {
        if (key == 0 || key != ref.key || len != (ref.bound - ref.i)) revert InvalidBlock();
    }

    function ensure(DataRef memory ref, bytes4 key, uint min, uint max) internal pure {
        uint len = ref.bound - ref.i;
        if (key == 0 || key != ref.key || len < min || (max != 0 && len > max)) revert InvalidBlock();
    }

    function ensure(DataPairRef memory ref, bytes4 key, uint len) internal pure {
        ensure(ref.a, key, len);
        ensure(ref.b, key, len);
    }

    function ensure(DataPairRef memory ref, bytes4 key, uint min, uint max) internal pure {
        ensure(ref.a, key, min, max);
        ensure(ref.b, key, min, max);
    }

    // ── *From ─────────────────────────────────────────────────────────────────

    function routeFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, ROUTE_KEY);
    }

    function nodeFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, NODE_KEY, 32);
    }

    function recipientFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, RECIPIENT_KEY, 32);
    }

    function partyFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, PARTY_KEY, 32);
    }

    function rateFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, RATE_KEY, 32);
    }

    function assetFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, ASSET_KEY, 64);
    }

    function fundingFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, FUNDING_KEY, 64);
    }

    function bountyFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, BOUNTY_KEY, 64);
    }

    function amountFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, AMOUNT_KEY, 96);
    }

    function amountTwoFrom(bytes calldata source, uint i) internal pure returns (DataPairRef memory ref, uint next) {
        (ref, next) = twoFrom(source, i);
        ensure(ref, AMOUNT_KEY, 96);
    }

    function balanceFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, BALANCE_KEY, 96);
    }

    function balanceTwoFrom(bytes calldata source, uint i) internal pure returns (DataPairRef memory ref, uint next) {
        (ref, next) = twoFrom(source, i);
        ensure(ref, BALANCE_KEY, 96);
    }

    function minimumFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, MINIMUM_KEY, 96);
    }

    function maximumFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, MAXIMUM_KEY, 96);
    }

    function listingFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, LISTING_KEY, 96);
    }

    function stepFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, STEP_KEY, 64, 0);
    }

    function authFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, AUTH_KEY, 149, 0);
    }

    function custodyFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, CUSTODY_KEY, 128);
    }

    function custodyTwoFrom(bytes calldata source, uint i) internal pure returns (DataPairRef memory ref, uint next) {
        (ref, next) = twoFrom(source, i);
        ensure(ref, CUSTODY_KEY, 128);
    }

    function allocationFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, ALLOCATION_KEY, 128);
    }

    function txFrom(bytes calldata source, uint i) internal pure returns (DataRef memory ref, uint next) {
        (ref, next) = from(source, i);
        ensure(ref, TX_KEY, 160);
    }

    // ── inner* ────────────────────────────────────────────────────────────────

    function innerRoute(DataRef memory parent) internal pure returns (bytes calldata data) {
        return unpackRoute(childAt(parent, parent.bound));
    }

    function innerNode(DataRef memory parent) internal pure returns (uint id) {
        return unpackNode(childAt(parent, parent.bound));
    }

    function innerRecipient(DataRef memory parent) internal pure returns (bytes32 account) {
        return unpackRecipient(childAt(parent, parent.bound));
    }

    function innerParty(DataRef memory parent) internal pure returns (bytes32 account) {
        return unpackParty(childAt(parent, parent.bound));
    }

    function innerRate(DataRef memory parent) internal pure returns (uint value) {
        return unpackRate(childAt(parent, parent.bound));
    }

    function innerAsset(DataRef memory parent) internal pure returns (bytes32 asset, bytes32 meta) {
        return unpackAsset(childAt(parent, parent.bound));
    }

    function innerFunding(DataRef memory parent) internal pure returns (uint host, uint amount) {
        return unpackFunding(childAt(parent, parent.bound));
    }

    function innerBounty(DataRef memory parent) internal pure returns (uint amount, bytes32 relayer) {
        return unpackBounty(childAt(parent, parent.bound));
    }

    function innerAmount(DataRef memory parent) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAmount(childAt(parent, parent.bound));
    }

    function innerAmountValue(DataRef memory parent) internal pure returns (AssetAmount memory) {
        return toAmountValue(childAt(parent, parent.bound));
    }

    function innerBalance(DataRef memory parent) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackBalance(childAt(parent, parent.bound));
    }

    function innerMinimum(DataRef memory parent) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMinimum(childAt(parent, parent.bound));
    }

    function innerMaximum(DataRef memory parent) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMaximum(childAt(parent, parent.bound));
    }

    function innerListing(DataRef memory parent) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        return unpackListing(childAt(parent, parent.bound));
    }

    function innerStep(DataRef memory parent) internal pure returns (uint target, uint value, bytes calldata req) {
        return unpackStep(childAt(parent, parent.bound));
    }

    function innerAuth(DataRef memory parent) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        return unpackAuth(childAt(parent, parent.bound));
    }

    function innerCustody(DataRef memory parent) internal pure returns (HostAmount memory value) {
        return toCustodyValue(childAt(parent, parent.bound));
    }

    function innerAllocation(DataRef memory parent) internal pure returns (HostAmount memory value) {
        return toAllocationValue(childAt(parent, parent.bound));
    }

    function innerTx(DataRef memory parent) internal pure returns (Tx memory value) {
        return toTxValue(childAt(parent, parent.bound));
    }

    // ── inner*At ──────────────────────────────────────────────────────────────

    function innerRouteAt(DataRef memory parent, uint i) internal pure returns (bytes calldata data) {
        return unpackRoute(childAt(parent, i));
    }

    function innerNodeAt(DataRef memory parent, uint i) internal pure returns (uint id) {
        return unpackNode(childAt(parent, i));
    }

    function innerRecipientAt(DataRef memory parent, uint i) internal pure returns (bytes32 account) {
        return unpackRecipient(childAt(parent, i));
    }

    function innerPartyAt(DataRef memory parent, uint i) internal pure returns (bytes32 account) {
        return unpackParty(childAt(parent, i));
    }

    function innerRateAt(DataRef memory parent, uint i) internal pure returns (uint value) {
        return unpackRate(childAt(parent, i));
    }

    function innerAssetAt(DataRef memory parent, uint i) internal pure returns (bytes32 asset, bytes32 meta) {
        return unpackAsset(childAt(parent, i));
    }

    function innerFundingAt(DataRef memory parent, uint i) internal pure returns (uint host, uint amount) {
        return unpackFunding(childAt(parent, i));
    }

    function innerBountyAt(DataRef memory parent, uint i) internal pure returns (uint amount, bytes32 relayer) {
        return unpackBounty(childAt(parent, i));
    }

    function innerAmountAt(
        DataRef memory parent,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAmount(childAt(parent, i));
    }

    function innerBalanceAt(
        DataRef memory parent,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackBalance(childAt(parent, i));
    }

    function innerMinimumAt(
        DataRef memory parent,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMinimum(childAt(parent, i));
    }

    function innerMaximumAt(
        DataRef memory parent,
        uint i
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackMaximum(childAt(parent, i));
    }

    function innerListingAt(
        DataRef memory parent,
        uint i
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        return unpackListing(childAt(parent, i));
    }

    function innerStepAt(
        DataRef memory parent,
        uint i
    ) internal pure returns (uint target, uint value, bytes calldata req) {
        return unpackStep(childAt(parent, i));
    }

    function innerAuthAt(
        DataRef memory parent,
        uint i
    ) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        return unpackAuth(childAt(parent, i));
    }

    function innerCustodyAt(DataRef memory parent, uint i) internal pure returns (HostAmount memory value) {
        return toCustodyValue(childAt(parent, i));
    }

    function innerAllocationAt(DataRef memory parent, uint i) internal pure returns (HostAmount memory value) {
        return toAllocationValue(childAt(parent, i));
    }

    function innerTxAt(DataRef memory parent, uint i) internal pure returns (Tx memory value) {
        return toTxValue(childAt(parent, i));
    }

    // ── unpack* ───────────────────────────────────────────────────────────────

    function unpackRoute(DataRef memory ref) internal pure returns (bytes calldata data) {
        ensure(ref, ROUTE_KEY);
        return msg.data[ref.i:ref.bound];
    }

    function unpackRouteUint(DataRef memory ref) internal pure returns (uint) {
        ensure(ref, ROUTE_KEY, 32);
        return uint(bytes32(msg.data[ref.i:ref.i + 32]));
    }

    function unpackRoute32(DataRef memory ref) internal pure returns (bytes32) {
        ensure(ref, ROUTE_KEY, 32);
        return bytes32(msg.data[ref.i:ref.i + 32]);
    }

    function unpackRoute64(DataRef memory ref) internal pure returns (bytes32 a, bytes32 b) {
        ensure(ref, ROUTE_KEY, 64);
        a = bytes32(msg.data[ref.i:ref.i + 32]);
        b = bytes32(msg.data[ref.i + 32:ref.i + 64]);
    }

    function unpackRoute96(DataRef memory ref) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        ensure(ref, ROUTE_KEY, 96);
        a = bytes32(msg.data[ref.i:ref.i + 32]);
        b = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        c = bytes32(msg.data[ref.i + 64:ref.i + 96]);
    }

    function unpackNode(DataRef memory ref) internal pure returns (uint id) {
        ensure(ref, NODE_KEY, 32);
        return uint(bytes32(msg.data[ref.i:ref.i + 32]));
    }

    function unpackRecipient(DataRef memory ref) internal pure returns (bytes32 account) {
        ensure(ref, RECIPIENT_KEY, 32);
        return bytes32(msg.data[ref.i:ref.i + 32]);
    }

    function unpackParty(DataRef memory ref) internal pure returns (bytes32 account) {
        ensure(ref, PARTY_KEY, 32);
        return bytes32(msg.data[ref.i:ref.i + 32]);
    }

    function unpackRate(DataRef memory ref) internal pure returns (uint value) {
        ensure(ref, RATE_KEY, 32);
        return uint(bytes32(msg.data[ref.i:ref.i + 32]));
    }

    function unpackAsset(DataRef memory ref) internal pure returns (bytes32 asset, bytes32 meta) {
        ensure(ref, ASSET_KEY, 64);
        return (bytes32(msg.data[ref.i:ref.i + 32]), bytes32(msg.data[ref.i + 32:ref.i + 64]));
    }

    function unpackFunding(DataRef memory ref) internal pure returns (uint host, uint amount) {
        ensure(ref, FUNDING_KEY, 64);
        host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        amount = uint(bytes32(msg.data[ref.i + 32:ref.i + 64]));
    }

    function unpackBounty(DataRef memory ref) internal pure returns (uint amount, bytes32 relayer) {
        ensure(ref, BOUNTY_KEY, 64);
        amount = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        relayer = bytes32(msg.data[ref.i + 32:ref.i + 64]);
    }

    function unpackAmount(DataRef memory ref) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, AMOUNT_KEY, 96);
        asset = bytes32(msg.data[ref.i:ref.i + 32]);
        meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackBalance(DataRef memory ref) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, BALANCE_KEY, 96);
        asset = bytes32(msg.data[ref.i:ref.i + 32]);
        meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackMinimum(DataRef memory ref) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, MINIMUM_KEY, 96);
        asset = bytes32(msg.data[ref.i:ref.i + 32]);
        meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackMaximum(DataRef memory ref) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, MAXIMUM_KEY, 96);
        asset = bytes32(msg.data[ref.i:ref.i + 32]);
        meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function unpackListing(DataRef memory ref) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        ensure(ref, LISTING_KEY, 96);
        host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
    }

    function unpackStep(DataRef memory ref) internal pure returns (uint target, uint value, bytes calldata req) {
        ensure(ref, STEP_KEY, 64, 0);
        target = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        value = uint(bytes32(msg.data[ref.i + 32:ref.i + 64]));
        req = msg.data[ref.i + 64:ref.bound];
    }

    function unpackAuth(DataRef memory ref) internal pure returns (uint cid, uint deadline, bytes calldata proof) {
        ensure(ref, AUTH_KEY, 149);
        cid = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        deadline = uint(bytes32(msg.data[ref.i + 32:ref.i + 64]));
        proof = msg.data[ref.i + 64:ref.bound];
    }

    // ── to*Value ──────────────────────────────────────────────────────────────

    function toAmountValue(DataRef memory ref) internal pure returns (AssetAmount memory value) {
        ensure(ref, AMOUNT_KEY, 96);
        value.asset = bytes32(msg.data[ref.i:ref.i + 32]);
        value.meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function toBalanceValue(DataRef memory ref) internal pure returns (AssetAmount memory value) {
        ensure(ref, BALANCE_KEY, 96);
        value.asset = bytes32(msg.data[ref.i:ref.i + 32]);
        value.meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function toMinimumValue(DataRef memory ref) internal pure returns (AssetAmount memory value) {
        ensure(ref, MINIMUM_KEY, 96);
        value.asset = bytes32(msg.data[ref.i:ref.i + 32]);
        value.meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function toMaximumValue(DataRef memory ref) internal pure returns (AssetAmount memory value) {
        ensure(ref, MAXIMUM_KEY, 96);
        value.asset = bytes32(msg.data[ref.i:ref.i + 32]);
        value.meta = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.amount = uint(bytes32(msg.data[ref.i + 64:ref.i + 96]));
    }

    function toListingValue(DataRef memory ref) internal pure returns (Listing memory value) {
        ensure(ref, LISTING_KEY, 96);
        value.host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        value.asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
    }

    function toCustodyValue(DataRef memory ref) internal pure returns (HostAmount memory value) {
        ensure(ref, CUSTODY_KEY, 128);
        value.host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        value.asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
        value.amount = uint(bytes32(msg.data[ref.i + 96:ref.i + 128]));
    }

    function toAllocationValue(DataRef memory ref) internal pure returns (HostAmount memory value) {
        ensure(ref, ALLOCATION_KEY, 128);
        value.host = uint(bytes32(msg.data[ref.i:ref.i + 32]));
        value.asset = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.meta = bytes32(msg.data[ref.i + 64:ref.i + 96]);
        value.amount = uint(bytes32(msg.data[ref.i + 96:ref.i + 128]));
    }

    function toTxValue(DataRef memory ref) internal pure returns (Tx memory value) {
        ensure(ref, TX_KEY, 160);
        value.from = bytes32(msg.data[ref.i:ref.i + 32]);
        value.to = bytes32(msg.data[ref.i + 32:ref.i + 64]);
        value.asset = bytes32(msg.data[ref.i + 64:ref.i + 96]);
        value.meta = bytes32(msg.data[ref.i + 96:ref.i + 128]);
        value.amount = uint(bytes32(msg.data[ref.i + 128:ref.i + 160]));
    }
}
