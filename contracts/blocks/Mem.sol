// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {BALANCE_KEY, CUSTODY_KEY, HostAmount, MemRef, TX_KEY, Tx} from "./Schema.sol";
import {InvalidBlock, MalformedBlocks} from "./Errors.sol";

library Mem {
    function from(bytes memory source, uint i) internal pure returns (MemRef memory ref) {
        uint eod = source.length;
        if (i == eod) return MemRef(bytes4(0), 0, 0, i);
        if (i > eod) revert MalformedBlocks();

        unchecked {
            ref.i = i + 12;
        }
        if (ref.i > eod) revert MalformedBlocks();

        bytes32 w;
        assembly ("memory-safe") {
            w := mload(add(add(source, 0x20), i))
        }

        ref.key = bytes4(w);
        ref.bound = ref.i + uint32(bytes4(w << 32));
        ref.end = ref.i + uint32(bytes4(w << 64));

        if (ref.bound > ref.end || ref.end > eod) revert MalformedBlocks();
    }

    function slice(bytes memory source, uint start, uint end) internal pure returns (bytes memory out) {
        if (end < start || end > source.length) revert MalformedBlocks();
        uint len = end - start;
        out = new bytes(len);
        if (len == 0) return out;

        assembly ("memory-safe") {
            mcopy(add(out, 0x20), add(add(source, 0x20), start), len)
        }
    }

    function count(bytes memory source, uint i, bytes4 key) internal pure returns (uint count_, uint next) {
        next = i;
        while (next < source.length) {
            MemRef memory ref = from(source, next);
            if (ref.key != key) break;
            unchecked {
                ++count_;
            }
            next = ref.end;
        }
    }

    function find(bytes memory source, uint i, uint limit, bytes4 key) internal pure returns (MemRef memory ref) {
        if (limit > source.length) revert MalformedBlocks();
        while (i < limit) {
            ref = from(source, i);
            if (ref.end > limit) revert MalformedBlocks();
            if (ref.key == key) return ref;
            i = ref.end;
        }

        return MemRef(bytes4(0), limit, limit, limit);
    }

    function ensure(MemRef memory ref, bytes4 key) internal pure {
        if (key == 0 || key != ref.key) revert InvalidBlock();
    }

    function ensure(MemRef memory ref, bytes4 key, uint len) internal pure {
        if (key == 0 || key != ref.key || len != (ref.bound - ref.i)) revert InvalidBlock();
    }

    function ensure(MemRef memory ref, bytes4 key, uint min, uint max) internal pure {
        uint len = ref.bound - ref.i;
        if (key == 0 || key != ref.key || len < min || (max != 0 && len > max)) revert InvalidBlock();
    }

    function unpackBalance(
        MemRef memory ref,
        bytes memory source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, BALANCE_KEY, 96);
        uint i = ref.i;

        assembly ("memory-safe") {
            let p := add(add(source, 0x20), i)
            asset := mload(p)
            meta := mload(add(p, 0x20))
            amount := mload(add(p, 0x40))
        }
    }

    function toCustodyValue(
        MemRef memory ref,
        bytes memory source
    ) internal pure returns (HostAmount memory value) {
        ensure(ref, CUSTODY_KEY, 128);
        uint i = ref.i;

        assembly ("memory-safe") {
            let p := add(add(source, 0x20), i)
            mstore(value, mload(p))
            mstore(add(value, 0x20), mload(add(p, 0x20)))
            mstore(add(value, 0x40), mload(add(p, 0x40)))
            mstore(add(value, 0x60), mload(add(p, 0x60)))
        }
    }

    function toTxValue(MemRef memory ref, bytes memory source) internal pure returns (Tx memory value) {
        ensure(ref, TX_KEY, 160);
        uint i = ref.i;

        assembly ("memory-safe") {
            let p := add(add(source, 0x20), i)
            mstore(value, mload(p))
            mstore(add(value, 0x20), mload(add(p, 0x20)))
            mstore(add(value, 0x40), mload(add(p, 0x40)))
            mstore(add(value, 0x60), mload(add(p, 0x60)))
            mstore(add(value, 0x80), mload(add(p, 0x80)))
        }
    }
}
