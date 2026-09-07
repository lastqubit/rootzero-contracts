// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions} from "../execution/Execution.sol";
import {Specs} from "../codec/Specs.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Buffers} from "../codec/Buffers.sol";

/// @dev Benchmark only. Production allocation policy is unchanged.
contract TestBufferAllocation {
    using Executions for Execution;

    // strategy: 0 = production scan, 1 = lazy, 2/3/4 = 1x/2x/4x input bytes.
    // strategy: 5 = divisible source hint, otherwise production runCount.
    // strategy: 7 = current production descriptor and allocation.
    // strategy: 6 = always ceiling-divide by the source hint, never scan.
    // workload: 0 = equal size, 1 = expanding, 2/3 = BYTES to BALANCE,
    // 4 = sparse, 5 = unused, 6/7 = under/overestimates, 8 = zero hint.
    function measure(uint strategy, uint workload, bytes calldata input, uint repetitions)
        external view returns (uint usedGas, uint retained, uint outputLength, bytes32 digest)
    {
        uint descriptor = Executions.describe(
            Specs.Empty,
            workload == 2 || workload == 3 || workload >= 6 ? Specs.Bytes : Specs.Amount,
            workload == 1 ? Specs.Position : Specs.Balance,
            0
        );
        // Artificial zero group size exercises lazy/fallback behavior.
        if (workload == 8) descriptor &= ~(uint(type(uint32).max) << 64);
        bytes memory output;
        uint startMemory;
        assembly ("memory-safe") { startMemory := mload(0x40) }
        uint startGas = gasleft();
        for (uint repetition; repetition < repetitions; ++repetition) {
            output = execute(strategy, workload, input, descriptor);
        }
        usedGas = startGas - gasleft();
        assembly ("memory-safe") { retained := sub(mload(0x40), startMemory) }
        outputLength = output.length;
        digest = keccak256(output);
    }

    function execute(uint strategy, uint workload, bytes calldata input, uint descriptor)
        private pure returns (bytes memory)
    {
        Execution memory exec;
        if (strategy == 7) {
            exec.openInput(descriptor, 0, input);
        } else {
            // Same decoder initialization as openInput, without the hint scan.
            uint decoders;
            assembly ("memory-safe") {
                decoders := or(or(input.offset, shl(32, add(input.offset, input.length))), shl(64, byte(9, descriptor)))
            }
            exec.decoders = decoders;
            uint capacity = strategy == 0 ? scannedCapacity(input, descriptor)
                : strategy == 6 ? ceilingCapacity(input.length, descriptor)
                : strategy == 5 ? hintedCapacity(input, descriptor)
                : strategy == 1 ? 0 : input.length * (1 << (strategy - 2));
            exec.writer = Buffers.cursor(capacity, uint8(descriptor >> 136));
        }
        uint index;
        while (exec.more()) {
            bytes32 asset;
            uint amount;
            if (workload == 2 || workload == 3 || workload >= 6) {
                bytes calldata payload = exec.unpackBytes();
                asset = bytes32(uint(1));
                amount = payload.length;
            } else {
                (asset, amount) = exec.unpackAmount();
            }
            if (workload == 1) {
                exec.outputPosition(asset, amount, bytes32(uint(2)), amount, bytes32(0));
            } else if (workload != 5 && (workload != 4 || index % 8 == 0)) {
                exec.outputBalance(asset, amount);
            }
            ++index;
        }
        return exec.finish();
    }

    function hintedCapacity(bytes calldata input, uint descriptor) private pure returns (uint) {
        uint sourceStride = uint8(descriptor >> 96);
        uint groupSize = uint32(descriptor >> 64);
        uint count;
        if (groupSize != 0 && input.length % groupSize == 0) {
            count = input.length / groupSize;
        } else if (sourceStride != 0) {
            uint start;
            assembly ("memory-safe") { start := input.offset }
            count = Blocks.runCount(start, start + input.length, bytes4(uint32(descriptor >> 104))) / sourceStride;
        }
        return count * uint32(descriptor >> 32);
    }

    function ceilingCapacity(uint length, uint descriptor) private pure returns (uint) {
        uint groupSize = uint32(descriptor >> 64);
        if (groupSize == 0) return 0;
        uint groups = length / groupSize;
        if (length % groupSize != 0) ++groups;
        return groups * uint32(descriptor >> 32);
    }

    function scannedCapacity(bytes calldata input, uint descriptor) private pure returns (uint) {
        uint start;
        assembly ("memory-safe") { start := input.offset }
        return (Blocks.runCount(start, start + input.length, bytes4(uint32(descriptor >> 104)))
            / uint8(descriptor >> 96)) * uint32(descriptor >> 32);
    }

}
