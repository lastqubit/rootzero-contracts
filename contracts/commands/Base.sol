// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {NodeCalls} from "../core/Calls.sol";
import {EndpointBase, Lane} from "../core/Endpoint.sol";
import {Cur} from "../Cursors.sol";
import {Keys} from "../blocks/Keys.sol";
import {Nodes} from "../utils/Nodes.sol";
import {Selectors} from "../utils/Selectors.sol";

/// @notice Execution context passed to every command invocation.
struct CommandContext {
    /// @dev Caller's account identifier.
    bytes32 account;
    /// @dev Current state block stream (previous command output or initial state).
    bytes state;
    /// @dev Input block stream for this invocation.
    bytes input;
}

/// @title CommandBase
/// @notice Abstract base for all rootzero command contracts.
/// Provides access control modifiers and command endpoint metadata helpers.
abstract contract CommandBase is NodeCalls, EndpointBase {
    /// @dev Thrown when `onlyActive` finds that `deadline` has already passed.
    error Expired();

    /// @dev Restrict execution to the commander using the host's admin account.
    modifier onlyAdmin(bytes32 account) {
        if (account != admin) revert AccessDenied();
        enforceCommander(msg.sender);
        _;
    }

    /// @dev Restrict execution to trusted callers.
    modifier onlyCommand() {
        enforceCaller(msg.sender);
        _;
    }

    /// @dev Restrict execution to invocations where `deadline` is in the future.
    /// @param deadline Unix timestamp after which the invocation is considered expired.
    modifier onlyActive(uint deadline) {
        if (deadline < block.timestamp) revert Expired();
        _;
    }

    /// @notice Publish command metadata and a default label.
    /// @param name Default human-readable command label and selector name.
    /// @param state Packed state lane plus optional group byte.
    /// @param input Packed input lane plus optional group byte.
    /// @param output Packed output lane plus optional group byte.
    /// @param selector Command ABI selector, or zero to derive it from `name`.
    /// @param funded Whether the command accepts nonzero native value.
    /// @param admin Whether the command is restricted to the admin account.
    /// @return id Command node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function command(
        string memory name,
        bytes9 state,
        bytes9 input,
        bytes9 output,
        bytes4 selector,
        bool funded,
        bool admin
    ) internal returns (uint id, bytes32 descriptor) {
        selector = selector == bytes4(0) ? Selectors.command(name) : selector;
        id = Nodes.toCommand(selector, address(this));
        descriptor = endpoint(id, name, state, input, output, funded, admin);
    }

    /// @notice Open input/state cursors and return the expected output block count.
    /// @param c Command invocation context.
    /// @param descriptor Packed command endpoint descriptor.
    /// @return input Cursor scoped to the command input lane.
    /// @return state Cursor scoped to the command state lane.
    /// @return outputs Number of output blocks implied by the matched group count.
    function openCommand(
        CommandContext calldata c,
        bytes32 descriptor
    ) internal pure returns (Cur memory input, Cur memory state, uint outputs) {
        uint groups;
        (input, groups, ) = openLane(c.input, descriptor, Lane.Input, 0);
        (state, , outputs) = openLane(c.state, descriptor, Lane.State, groups);
    }
}
