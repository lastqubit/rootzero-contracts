// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "../core/Access.sol";
import {GuardEvent} from "../events/Guard.sol";
import {LabeledEvent} from "../events/Labeled.sol";
import {Ids} from "../utils/Ids.sol";

/// @notice ABI-encode a guard action call from a target guard ID and request block stream.
/// @dev Derives the function selector from `target` via `Ids.guardSelector(target)`.
/// Reverts if `target` is not a valid guard ID.
/// @param target Destination guard action node ID embedding the target selector.
/// @param request Input block stream for the guard invocation.
/// @return ABI-encoded calldata for the guard action entry point.
function encodeGuardCall(uint target, bytes calldata request) pure returns (bytes memory) {
    bytes4 selector = Ids.guardSelector(target);
    return abi.encodeWithSelector(selector, request);
}

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
        return Ids.toGuard(selector, address(this));
    }
}
