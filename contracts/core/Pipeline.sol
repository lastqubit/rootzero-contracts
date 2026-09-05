// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks} from "../codec/Blocks.sol";
import {Keys} from "../codec/Keys.sol";
import {CommandAccess} from "./Access.sol";
import {InsufficientValue, OutOfBounds, UnexpectedState} from "../utils/Errors.sol";
import {Flags} from "../utils/Flags.sol";

/// @notice Hook implemented by hosts that execute encoded step streams.
abstract contract PipeHook {
    /// @notice Execute a step stream and return its remaining native-value budget.
    function pipe(
        bytes32 account,
        bytes memory state,
        bytes calldata steps,
        uint budget
    ) internal virtual returns (uint remaining);
}

/// @notice Hook implemented by pipeline hosts that execute host-local commands.
abstract contract ExecuteHook {
    /// @notice Try to execute one command whose node ID targets the current host.
    /// @dev Implementations returning `handled = true` are responsible for
    /// authorizing the command. Return false without side effects to delegate to
    /// the trusted normal external entrypoint. Handoff commands must be delegated
    /// because this hook receives ordinary input without the continuation that
    /// Pipeline adds to the RELAY envelope. Implementations may revert instead.
    function execute(
        uint cmd,
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint value
    ) internal virtual returns (bool handled, bytes memory output, uint credit);
}

/// @title Pipeline
/// @notice Core pipeline functionality shared by higher-level surfaces.
/// @dev This gas-sensitive implementation intentionally inlines the command ID
/// layout and the CONTEXT, BYTES, and RELAY block encodings. Changes to command
/// selector, target, or flag placement, or to those block layouts, must update
/// the corresponding assembly and packed-cursor logic here.
abstract contract Pipeline is CommandAccess, PipeHook, ExecuteHook {
    /// @dev Private pipeline cursor layout:
    /// bits 0-31 current STEP offset, 32-63 stream end,
    /// 64-95 command-input offset, 96-127 command-input length.
    function unpackBytes(uint abs) private pure returns (uint input, uint end) {
        uint body;
        (body, end) = Blocks.enter(abs, Keys.Bytes);
        // Key-only `enter` constructs `end` as `body + uint32(length)`.
        unchecked {
            input = uint32(body) | ((end - body) << 32);
        }
    }

    function takeStep(uint cursor) private pure returns (uint cmd, uint value, uint updated) {
        uint abs = uint32(cursor);
        uint limit;
        (abs, limit) = Blocks.enter(abs, Keys.Step);
        assembly ("memory-safe") {
            cmd := calldataload(abs)
            value := calldataload(add(abs, 0x20))
        }

        (uint input, uint end) = unpackBytes(abs + 64);
        if (end != limit) revert Blocks.InvalidBlock();
        if (end > uint32(cursor >> 32)) revert OutOfBounds();

        updated = uint32(end) | (uint64(cursor) & (uint(type(uint32).max) << 32)) | (input << 64);
    }

    function rawInput(uint cursor) private pure returns (bytes calldata input) {
        assembly ("memory-safe") {
            input.offset := and(shr(64, cursor), 0xffffffff)
            input.length := and(shr(96, cursor), 0xffffffff)
        }
    }

    /// @dev Execute the prepared command call and strictly decode `(bytes, uint)`.
    /// `run` passes either a 64-bit input offset/length pair for ordinary calls,
    /// or the complete cursor for handoffs. A complete cursor always has a nonzero
    /// command-input offset in bits 64-95, even when that input is empty, because
    /// takeStep obtained it from a BYTES block inside the current calldata.
    function invokeCommand(
        bytes4 selector,
        address target,
        uint value,
        bytes32 account,
        bytes memory state,
        uint input
    ) private returns (bytes memory output, uint credit) {
        assembly ("memory-safe") {
            let scratch := mload(0x40)
            let ctxlen
            switch iszero(shr(64, input))
            case 1 {
                let statelen := mload(state)
                let inputlen := and(shr(32, input), 0xffffffff)
                ctxlen := add(56, add(statelen, inputlen))

                mstore(scratch, selector)
                mstore(add(scratch, 0x04), 0x20)
                mstore(add(scratch, 0x24), ctxlen)

                let p := add(scratch, 0x44)
                mstore(p, or(shl(224, 0xc5769e23), shl(192, sub(ctxlen, 8))))
                mstore(add(p, 0x08), account)
                p := add(p, 0x28)
                mstore(p, or(shl(224, 0x6911b332), shl(192, statelen)))
                mcopy(add(p, 0x08), add(state, 0x20), statelen)
                p := add(add(p, 0x08), statelen)
                mstore(p, or(shl(224, 0x6911b332), shl(192, inputlen)))
                calldatacopy(add(p, 0x08), and(input, 0xffffffff), inputlen)
            }
            default {
                let statelen := mload(state)
                let inputlen := and(shr(96, input), 0xffffffff)
                let stepslen := sub(and(shr(32, input), 0xffffffff), and(input, 0xffffffff))
                let relaylen := add(16, add(inputlen, stepslen))
                ctxlen := add(64, add(statelen, relaylen))

                mstore(scratch, selector)
                mstore(add(scratch, 0x04), 0x20)
                mstore(add(scratch, 0x24), ctxlen)

                let p := add(scratch, 0x44)
                mstore(p, or(shl(224, 0xc5769e23), shl(192, sub(ctxlen, 8))))
                mstore(add(p, 0x08), account)
                p := add(p, 0x28)
                mstore(p, or(shl(224, 0x6911b332), shl(192, statelen)))
                mcopy(add(p, 0x08), add(state, 0x20), statelen)

                p := add(add(p, 0x08), statelen)
                mstore(p, or(shl(224, 0x6911b332), shl(192, add(8, relaylen))))
                p := add(p, 0x08)
                mstore(p, or(shl(224, 0xc34cc52a), shl(192, relaylen)))
                p := add(p, 0x08)
                mstore(p, or(shl(224, 0x6911b332), shl(192, inputlen)))
                calldatacopy(add(p, 0x08), and(shr(64, input), 0xffffffff), inputlen)
                p := add(add(p, 0x08), inputlen)
                mstore(p, or(shl(224, 0x6911b332), shl(192, stepslen)))
                calldatacopy(add(p, 0x08), and(input, 0xffffffff), stepslen)
            }
            // Temporary memory can be dirty; canonical ABI bytes padding is zero.
            mstore(add(add(scratch, 0x44), ctxlen), 0)
            ctxlen := add(68, and(add(ctxlen, 0x1f), not(0x1f)))
            let success := call(
                gas(),
                and(target, 0xffffffffffffffffffffffffffffffffffffffff),
                value,
                scratch,
                ctxlen,
                0,
                0
            )
            let retlen := returndatasize()
            if iszero(success) {
                mstore(scratch, shl(224, 0x20577b07))
                mstore(add(scratch, 0x04), and(target, 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(scratch, 0x24), shl(224, shr(224, selector)))
                mstore(add(scratch, 0x44), 0x60)
                mstore(add(scratch, 0x64), retlen)
                mstore(add(add(scratch, 0x84), retlen), 0)
                returndatacopy(add(scratch, 0x84), 0, retlen)
                revert(scratch, add(0x84, and(add(retlen, 0x1f), not(0x1f))))
            }

            if lt(retlen, 0x60) {
                revert(0, 0)
            }
            returndatacopy(scratch, 0, retlen)
            if iszero(eq(mload(scratch), 0x40)) {
                revert(0, 0)
            }
            let len1 := mload(add(scratch, 0x40))
            if gt(len1, sub(retlen, 0x60)) {
                revert(0, 0)
            }
            let pad1 := and(add(len1, 0x1f), not(0x1f))
            if iszero(eq(retlen, add(0x60, pad1))) {
                revert(0, 0)
            }
            output := add(scratch, 0x40)
            credit := mload(add(scratch, 0x20))

            let retend := and(add(add(scratch, retlen), 0x1f), not(0x1f))
            // Only returndata survives this call. The encoded input was temporary
            // and its remaining memory can be reused by later pipeline steps.
            mstore(0x40, retend)
        }
    }

    function run(
        uint cmd,
        bytes32 account,
        bytes memory state,
        uint value,
        uint cursor
    ) private returns (bytes memory output, uint credit, uint updated) {
        if (address(uint160(cmd)) == address(this)) {
            bool handled;
            (handled, output, credit) = execute(cmd, account, state, rawInput(cursor), value);
            if (handled) return (output, credit, cursor);
        }
        (bytes4 selector, address target) = enforceCommand(cmd);
        bool handoff = uint8(cmd >> 224) & Flags.Handoff != 0;
        (output, credit) = invokeCommand(selector, target, value, account, state, handoff ? cursor : cursor >> 64);
        updated = handoff ? (cursor & ~uint(type(uint32).max)) | uint32(cursor >> 32) : cursor;
    }

    /// @notice Execute a STEP block stream through the pipeline.
    /// @dev Reverts with `UnexpectedState` if the final threaded state is non-empty.
    /// Callers remain responsible for settling the returned unspent value.
    /// @param account Account identifier used for each dispatched step.
    /// @param state Initial state block stream passed to the first step.
    /// @param steps STEP block stream to execute.
    /// @param budget Native-value budget shared across all steps.
    /// @return remaining Native value remaining after every step executes.
    function pipe(
        bytes32 account,
        bytes memory state,
        bytes calldata steps,
        uint budget
    ) internal virtual override returns (uint remaining) {
        uint cursor;
        assembly ("memory-safe") {
            cursor := or(steps.offset, shl(32, add(steps.offset, steps.length)))
        }

        while (uint32(cursor) < uint32(cursor >> 32)) {
            uint cmd;
            uint value;
            (cmd, value, cursor) = takeStep(cursor);
            if (value > budget) revert InsufficientValue();
            unchecked {
                budget -= value;
            }
            (state, value, cursor) = run(cmd, account, state, value, cursor);
            budget += value;
        }

        if (state.length != 0) revert UnexpectedState();
        return budget;
    }
}
