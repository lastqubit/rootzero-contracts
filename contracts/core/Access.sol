// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {NodeEvent} from "../events/Node.sol";
import {GuardianEvent} from "../events/Guardian.sol";
import {Runtime} from "./Runtime.sol";
import {Accounts} from "../utils/Accounts.sol";
import {Nodes} from "../utils/Nodes.sol";
import {addrOr} from "../utils/Utils.sol";

/// @title AccessControl
/// @notice Host access control layer.
/// Tracks an immutable trusted commander, the host's own node ID, and a
/// mapping of externally trusted node IDs. Inbound trust is host-based:
/// trusted hosts, the commander, and this contract itself may interact
/// with the host through the guarded command and peer entrypoints.
abstract contract AccessControl is Runtime, NodeEvent, GuardianEvent {
    /// @dev Trusted commander address. All calls from this address are implicitly trusted.
    /// Defaults to `address(this)` when no external commander is provided.
    address internal immutable commander;
    /// @dev Admin account ID derived from the commander address at construction time.
    bytes32 internal immutable admin;

    /// @dev Mapping from guardian account ID to guardian status.
    mapping(bytes32 account => bool) internal guardians;

    /// @dev Mapping from node ID to trust status.
    mapping(uint node => bool) internal nodes;

    /// @dev Thrown when a caller, account, or node lacks required access.
    error AccessDenied();

    constructor(address cmdr) {
        commander = addrOr(cmdr, address(this));
        admin = Accounts.toAdmin(commander);
    }

    /// @notice Set authorization status for a node.
    /// @param node Node ID to update.
    /// @param active True to authorize the node, false to revoke it.
    function setNode(uint node, bool active) internal {
        nodes[node] = active;
        emit Node(host, node, active);
    }

    /// @notice Set guardian status for an account.
    /// @param account Guardian account ID to update.
    /// @param active True to enable the guardian, false to revoke it.
    function setGuardian(bytes32 account, bool active) internal {
        Accounts.guardian(account);
        guardians[account] = active;
        emit Guardian(host, account, active);
    }

    /// @notice Return true if `addr` is an active guardian.
    /// @param addr EVM address to check as a guardian account.
    function isGuardian(address addr) internal view returns (bool) {
        return guardians[Accounts.toGuardian(addr)];
    }

    /// @notice Return true if `caller` is an implicitly trusted address.
    /// Trusted callers: the commander, this contract itself, or any address
    /// whose host ID has been explicitly authorized.
    /// @param caller Address to check.
    function isTrusted(address caller) internal view returns (bool) {
        return caller == commander || caller == address(this) || nodes[Nodes.toHost(caller)];
    }

    /// @notice Assert that `node` is in the trusted set and return it.
    /// @param node Node ID to validate.
    /// @return The same `node` value if trusted.
    function ensureTrusted(uint node) internal view returns (uint) {
        if (node == 0 || !nodes[node]) {
            revert AccessDenied();
        }
        return node;
    }

    /// @notice Assert that `caller` is trusted and return it.
    /// Used by command and peer modifiers to gate execution to authorized senders.
    /// @param caller Address to validate.
    /// @return The same `caller` value if trusted.
    function enforceCaller(address caller) internal view returns (address) {
        if (caller == address(0) || !isTrusted(caller)) {
            revert AccessDenied();
        }
        return caller;
    }

    /// @notice Assert that `caller` is the commander and return it.
    /// Used by admin modifiers to keep governance authority separate from peer trust.
    /// @param caller Address to validate.
    /// @return The same `caller` value if it is the commander.
    function enforceCommander(address caller) internal view returns (address) {
        if (caller == address(0) || caller != commander) {
            revert AccessDenied();
        }
        return caller;
    }
}
