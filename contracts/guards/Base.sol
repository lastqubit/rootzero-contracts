// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {InputEndpointBase} from "../core/Endpoint.sol";
import {GuardianAccess} from "../core/Access.sol";
import {Specs} from "../codec/Specs.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @title GuardBase
/// @notice Abstract base for guardian-only direct host actions.
/// Guard actions are non-payable direct calls with no command context, state, or response.
abstract contract GuardBase is InputEndpointBase, GuardianAccess {
    /// @dev Restrict execution to active guardian addresses.
    modifier onlyGuardian() {
        enforceGuardian(msg.sender);
        _;
    }

    /// @notice Publish guard metadata and a default label.
    /// @param name Guard entrypoint name and default label. It must exactly
    /// match the Solidity guard function name used by the canonical ABI.
    /// @param input Input block specification.
    /// @return id Guard action node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function guard(
        string memory name,
        uint input
    ) internal returns (uint id, uint descriptor) {
        id = Nodes.toGuard(name, address(this));
        descriptor = endpoint(id, name, Specs.Empty, input, Specs.Empty, 0);
    }
}
