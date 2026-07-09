// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {NodeCalls} from "../core/Calls.sol";
import {EndpointBase} from "../core/Endpoint.sol";
import {Cursors, Cur} from "../Cursors.sol";
import {Keys} from "../blocks/Keys.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @notice Execution context passed to every command invocation.
struct CommandContext {
    /// @dev Caller's account identifier.
    bytes32 account;
    /// @dev Current state block stream (previous command output or initial state).
    bytes state;
    /// @dev Input block stream for this invocation.
    bytes request;
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
    function command(
        string memory name,
        bytes9 state,
        bytes9 input,
        bytes9 output,
        bytes4 selector,
        bool funded,
        bool admin
    ) internal returns (uint id, bytes32 descriptor) {
        if (selector == bytes4(0)) {
            selector = bytes4(keccak256(bytes(string.concat(name, "((bytes32,bytes,bytes))"))));
        }
        id = Nodes.toCommand(selector, address(this));
        descriptor = endpoint(state, input, output, funded, admin);
        defineEndpoint(host, id, descriptor, name);
    }

    /// @notice Open a command state cursor and return the expected output block count.
    function openState(
        CommandContext calldata c,
        bytes32 descriptor
    ) internal pure returns (Cur memory state, uint outputs) {
        uint groups;
        (state, groups) = Cursors.init(c.state, stateGroup(descriptor));
        outputs = groups * outputGroup(descriptor);
    }

    /// @notice Open input/state cursors and return the expected output block count.
    function openCommand(
        CommandContext calldata c,
        bytes32 descriptor
    ) internal pure returns (Cur memory input, Cur memory state, uint outputs) {
        uint requestGroup = inputGroup(descriptor);
        uint stateGroup_ = stateGroup(descriptor);

        uint groups;
        (input, groups) = Cursors.init(c.request, requestGroup);

        uint stateGroups;
        (state, stateGroups) = Cursors.init(c.state, stateGroup_);

        if (requestGroup == 0) {
            groups = stateGroups;
        } else if (stateGroup_ != 0 && stateGroups != groups) {
            revert Cursors.BadRatio();
        }

        outputs = groups * outputGroup(descriptor);
    }
}
