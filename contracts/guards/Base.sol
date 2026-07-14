// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "../core/Access.sol";
import {EndpointBase} from "../core/Endpoint.sol";
import {Nodes} from "../utils/Nodes.sol";
import {Selectors} from "../utils/Selectors.sol";

/// @title GuardBase
/// @notice Abstract base for guardian-only direct host actions.
/// Guard actions are non-payable direct calls with no command context, state, or response.
abstract contract GuardBase is AccessControl, EndpointBase {
    /// @dev Restrict execution to active guardian addresses.
    modifier onlyGuardian() {
        if (!isGuardian(msg.sender)) revert AccessDenied();
        _;
    }

    /// @notice Publish guard metadata and a default label.
    function guard(
        string memory name,
        bytes9 input,
        bytes4 selector
    ) internal returns (uint id, bytes32 descriptor) {
        if (selector == bytes4(0)) {
            selector = Selectors.guard(name);
        }
        id = Nodes.toGuard(selector, address(this));
        descriptor = endpoint(id, name, bytes9(0), input, bytes9(0), false, false);
    }
}
