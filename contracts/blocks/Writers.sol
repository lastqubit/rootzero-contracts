// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Blocks} from "./Readers.sol";
import {MalformedBlocks} from "./Errors.sol";
import {AssetAmount, BALANCE_KEY, CUSTODY_KEY, HostAmount, TX_KEY, Tx, Writer} from "./Schema.sol";

error WriterOverflow();
error IncompleteWriter();
error EmptyRequest();

uint constant ALLOC_SCALE = 10_000;
uint constant BALANCE_BLOCK_LEN = 108;
uint constant CUSTODY_BLOCK_LEN = 140;
uint constant TX_BLOCK_LEN = 172;

library Writers {
    // Encodes a 12-byte block header (4-byte key + 4-byte selfLen + 4-byte totalLen) into a uint so assembly can
    // write the full header in one mstore while the payload starts at offset + 12.
    function toBlockHeader(bytes4 key, uint selfLen, uint totalLen) internal pure returns (uint) {
        if (selfLen > type(uint32).max || totalLen > type(uint32).max || selfLen > totalLen) revert MalformedBlocks();
        return (uint(uint32(key)) << 224) | (uint(uint32(selfLen)) << 192) | (uint(uint32(totalLen)) << 160);
    }

    function alloc(uint len) internal pure returns (Writer memory writer) {
        writer = Writer({i: 0, end: len, dst: new bytes(len)});
    }

    function append(Writer memory writer, bytes memory data) internal pure {
        uint next = writer.i + data.length;
        if (next > writer.dst.length) revert WriterOverflow();
        assembly ("memory-safe") {
            mcopy(add(add(mload(add(writer, 0x40)), 0x20), mload(writer)), add(data, 0x20), mload(data))
        }
        writer.i = next;
    }

    function allocBalancesFrom(
        bytes calldata blocks,
        uint i,
        bytes4 source
    ) internal pure returns (Writer memory writer, uint next) {
        return allocFromScaledCount(blocks, i, source, ALLOC_SCALE, BALANCE_BLOCK_LEN);
    }

    function allocPairedBalancesFrom(
        bytes calldata blocks,
        uint i,
        bytes4 source
    ) internal pure returns (Writer memory writer, uint next) {
        return allocFromScaledCount(blocks, i, source, ALLOC_SCALE * 2, BALANCE_BLOCK_LEN);
    }

    function allocScaledBalancesFrom(
        bytes calldata blocks,
        uint i,
        bytes4 source,
        uint scaledRatio
    ) internal pure returns (Writer memory writer, uint next) {
        return allocFromScaledCount(blocks, i, source, scaledRatio, BALANCE_BLOCK_LEN);
    }

    function allocTxsFrom(
        bytes calldata blocks,
        uint i,
        bytes4 source
    ) internal pure returns (Writer memory writer, uint next) {
        return allocFromScaledCount(blocks, i, source, ALLOC_SCALE, TX_BLOCK_LEN);
    }

    function allocCustodiesFrom(
        bytes calldata blocks,
        uint i,
        bytes4 source
    ) internal pure returns (Writer memory writer, uint next) {
        return allocFromScaledCount(blocks, i, source, ALLOC_SCALE, CUSTODY_BLOCK_LEN);
    }

    function allocScaledCustodiesFrom(
        bytes calldata blocks,
        uint i,
        bytes4 source,
        uint scaledRatio
    ) internal pure returns (Writer memory writer, uint next) {
        return allocFromScaledCount(blocks, i, source, scaledRatio, CUSTODY_BLOCK_LEN);
    }

    function allocFromScaledCount(
        bytes calldata blocks,
        uint i,
        bytes4 source,
        uint scaledRatio,
        uint blockLen
    ) internal pure returns (Writer memory writer, uint next) {
        uint count;
        (count, next) = Blocks.count(blocks, i, source);
        if (count == 0) revert EmptyRequest();
        uint scaledCount = count * scaledRatio;
        if (scaledCount % ALLOC_SCALE != 0) revert MalformedBlocks();
        uint len = (scaledCount / ALLOC_SCALE) * blockLen;
        writer = Writer({i: 0, end: len, dst: new bytes(len)});
    }

    function writeBalanceBlock(bytes memory dst, uint i, AssetAmount memory value) internal pure returns (uint next) {
        next = i + BALANCE_BLOCK_LEN;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(BALANCE_KEY, 96, 96);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x0c), mload(value))
            mstore(add(p, 0x2c), mload(add(value, 0x20)))
            mstore(add(p, 0x4c), mload(add(value, 0x40)))
        }
    }

    function appendBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendBalance(writer, AssetAmount(asset, meta, amount));
    }

    function appendBalance(Writer memory writer, AssetAmount memory value) internal pure {
        writer.i = writeBalanceBlock(writer.dst, writer.i, value);
    }

    function appendNonZeroBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        if (amount > 0) appendBalance(writer, asset, meta, amount);
    }

    function appendNonZeroBalance(Writer memory writer, AssetAmount memory value) internal pure {
        if (value.amount > 0) appendBalance(writer, value);
    }

    function writeCustodyBlock(bytes memory dst, uint i, HostAmount memory value) internal pure returns (uint next) {
        next = i + CUSTODY_BLOCK_LEN;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(CUSTODY_KEY, 128, 128);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x0c), mload(value))
            mstore(add(p, 0x2c), mload(add(value, 0x20)))
            mstore(add(p, 0x4c), mload(add(value, 0x40)))
            mstore(add(p, 0x6c), mload(add(value, 0x60)))
        }
    }

    function appendCustody(Writer memory writer, uint host, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendCustody(writer, HostAmount(host, asset, meta, amount));
    }

    function appendCustody(Writer memory writer, HostAmount memory value) internal pure {
        writer.i = writeCustodyBlock(writer.dst, writer.i, value);
    }

    function writeTxBlock(bytes memory dst, uint i, Tx memory value) internal pure returns (uint next) {
        next = i + TX_BLOCK_LEN;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(TX_KEY, 160, 160);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x0c), mload(value))
            mstore(add(p, 0x2c), mload(add(value, 0x20)))
            mstore(add(p, 0x4c), mload(add(value, 0x40)))
            mstore(add(p, 0x6c), mload(add(value, 0x60)))
            mstore(add(p, 0x8c), mload(add(value, 0x80)))
        }
    }

    function appendTx(Writer memory writer, Tx memory value) internal pure {
        writer.i = writeTxBlock(writer.dst, writer.i, value);
    }

    function done(Writer memory writer) internal pure returns (bytes memory) {
        if (writer.i != writer.dst.length) revert IncompleteWriter();
        return writer.dst;
    }

    function finish(Writer memory writer) internal pure returns (bytes memory out) {
        if (writer.i == 0) revert EmptyRequest();
        if (writer.i > writer.dst.length) revert IncompleteWriter();
        out = writer.dst;
        assembly ("memory-safe") {
            mstore(out, mload(writer))
        }
    }
}
