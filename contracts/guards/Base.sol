// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "../core/Access.sol";
import {EndpointBase} from "../core/Endpoint.sol";
import {Specs} from "../codec/Specs.sol";
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
    /// @param name Default human-readable guard label and selector name.
    /// @param input Input block specification.
    /// @param selector Guard ABI selector, or zero to derive it from `name`.
    /// @return id Guard action node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function guard(
        string memory name,
        uint input,
        bytes4 selector
    ) internal returns (uint id, uint descriptor) {
        selector = selector == bytes4(0) ? Selectors.guard(name) : selector;
        id = Nodes.toGuard(selector, address(this));
        descriptor = endpoint(id, name, Specs.Empty, input, Specs.Empty, false, false);
    }
}
