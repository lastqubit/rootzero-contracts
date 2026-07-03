// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "../core/Access.sol";
import {GuardEvent} from "../events/Guard.sol";
import {LabeledEvent} from "../events/Labeled.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @title GuardBase
/// @notice Abstract base for guardian-only direct host actions.
/// Guard actions are non-payable direct calls with no command context, state, or response.
abstract contract GuardBase is AccessControl, GuardEvent, LabeledEvent {
    /// @dev Restrict execution to active guardian addresses.
    modifier onlyGuardian() {
        if (!isGuardian(msg.sender)) revert AccessDenied();
        _;
    }

    /// @notice Derive the deterministic node ID for a guard action selector on this contract.
    /// @param selector Guard action entrypoint selector.
    /// @return Guard action node ID.
    function guardId(bytes4 selector) internal view returns (uint) {
        return Nodes.toGuard(selector, address(this));
    }
}
