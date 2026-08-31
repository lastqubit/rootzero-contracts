// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {NodeEvent} from "../events/Node.sol";
import {GuardianEvent} from "../events/Guardian.sol";
import {Runtime} from "./Runtime.sol";
import {Accounts} from "../utils/Accounts.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @dev Thrown when a caller, account, or node lacks required access.
error AccessDenied();
error CommanderNotAllowed();

/// @notice Assert that `msg.sender` equals `expected` and return it.
/// @param expected Address required to be the current message sender.
/// @return The validated sender address.
function enforceSender(address expected) view returns (address) {
    if (msg.sender != expected) revert AccessDenied();
    return expected;
}

/// @title CallerAccess
/// @notice Authorization capability required by command entrypoints.
abstract contract CallerAccess is Runtime {
    /// @notice Assert that `caller` may invoke a command and return it.
    function enforceCaller(address caller) internal view virtual returns (address);
}

/// @title CommandAccess
/// @notice Authorization capability required by outbound command execution.
abstract contract CommandAccess {
    /// @notice Assert that `command` is a trusted command ID and resolve its EVM endpoint.
    /// @return selector ABI selector encoded by the command ID.
    /// @return target Contract address encoded by the command ID.
    function enforceCommand(uint command) internal view virtual returns (bytes4 selector, address target);
}

/// @title PortAccess
/// @notice Authorization capability required by outbound port calls.
abstract contract PortAccess {
    /// @notice Assert that `port` is a trusted port ID and resolve its EVM endpoint.
    /// @return selector ABI selector encoded by the port ID.
    /// @return target Contract address encoded by the port ID.
    function enforcePort(uint port) internal view virtual returns (bytes4 selector, address target);
}

/// @title PeerAccess
/// @notice Authorization capability required by inbound peer endpoints.
abstract contract PeerAccess {
    /// @notice Assert that `caller` is an authorized peer and return it.
    function enforcePeer(address caller) internal view virtual returns (address);
}

/// @title CommanderAccess
/// @notice Minimal commander-based access control shared by host access policies.
abstract contract CommanderAccess is Runtime {
    /// @dev Commander host ID. Defaults to this contract's host ID when self-managed.
    uint internal immutable commander;

    /// @dev Native commander address resolved from `commander` at construction.
    address internal immutable commanderAddr;

    /// @param cmdr Local host ID of the commander, or zero to make this contract self-managed.
    constructor(uint cmdr) {
        commander = cmdr == 0 ? host : cmdr;
        commanderAddr = cmdr == 0 ? address(this) : Nodes.hostAddr(cmdr);
    }

    /// @notice Assert that `caller` is the commander and return it.
    /// @param caller Address to validate.
    /// @return The same `caller` value if it is the commander.
    function enforceCommander(address caller) internal view returns (address) {
        if (caller == address(0) || caller != commanderAddr) {
            revert AccessDenied();
        }
        return caller;
    }

}

/// @title AdminAccess
/// @notice Commander access with the admin account derived from the commander.
abstract contract AdminAccess is CommanderAccess {
    /// @dev Admin account ID derived from the resolved commander address at construction time.
    bytes32 internal immutable admin;

    constructor() {
        admin = Accounts.toAdmin(commanderAddr);
    }

    /// @notice Assert that `account` is the admin account and `caller` is the commander.
    function enforceAdmin(bytes32 account, address caller) internal view returns (bytes32) {
        if (account != admin) revert AccessDenied();
        enforceCommander(caller);
        return account;
    }
}

/// @title NodeAccess
/// @notice Admin access extended with externally trusted node IDs.
/// Inbound trust is host-based:
/// trusted hosts, the commander, and this contract itself may interact
/// with the host through the guarded command and peer entrypoints.
abstract contract NodeAccess is PeerAccess, AdminAccess, CommandAccess, PortAccess, NodeEvent {
    /// @dev Mapping from node ID to trust status.
    mapping(uint node => bool) internal nodes;

    /// @notice Set authorization status for a node.
    /// @param node Node ID to update.
    /// @param active True to authorize the node, false to revoke it.
    function setNode(uint node, bool active) internal {
        node = Nodes.local(node);
        nodes[node] = active;
        emit Node(host, node, active);
    }

    /// @notice Return true if `caller` is an implicitly trusted address.
    /// Trusted callers: the commander, this contract itself, or any address
    /// whose host ID has been explicitly authorized.
    /// @param caller Address to check.
    function isTrustedCaller(address caller) internal view returns (bool) {
        return caller == commanderAddr || caller == address(this) || nodes[Nodes.toHost(caller)];
    }

    /// @notice Assert that `node` is in the trusted set and resolve its endpoint.
    function enforceTrusted(uint node) internal view returns (bytes4 selector, address target) {
        if (!nodes[node]) revert AccessDenied();
        selector = bytes4(uint32(node >> 160));
        target = address(uint160(node));
    }

    /// @notice Assert that `command` is a command ID in the trusted set and resolve its endpoint.
    function enforceCommand(uint command) internal view override returns (bytes4 selector, address target) {
        return enforceTrusted(Nodes.command(command));
    }

    /// @notice Assert that `port` is a port ID in the trusted set and resolve its endpoint.
    function enforcePort(uint port) internal view override returns (bytes4 selector, address target) {
        return enforceTrusted(Nodes.port(port));
    }

    /// @notice Assert that `caller` is a trusted peer other than the commander.
    function enforcePeer(address caller) internal view override returns (address) {
        if (caller == commanderAddr) revert CommanderNotAllowed();
        if (caller == address(0) || !isTrustedCaller(caller)) {
            revert AccessDenied();
        }
        return caller;
    }

}

/// @title GuardianAccess
/// @notice Guardian identity storage and authorization capability.
abstract contract GuardianAccess is GuardianEvent {
    /// @dev Mapping from user account ID to guardian status.
    mapping(bytes32 account => bool) internal guardians;

    /// @notice Set guardian status for an account.
    /// @param account User account ID whose guardian role is updated.
    /// @param active True to enable the guardian, false to revoke it.
    function setGuardian(bytes32 account, bool active) internal {
        account = Accounts.user(account);
        guardians[account] = active;
        emit Guardian(Nodes.toHost(address(this)), account, active);
    }

    /// @notice Return true if `addr` is an active guardian.
    /// @param addr EVM address to check for the guardian role.
    function isGuardian(address addr) internal view returns (bool) {
        return guardians[Accounts.toUser(addr)];
    }

    /// @notice Assert that `caller` is an active guardian and return it.
    function enforceGuardian(address caller) internal view returns (address) {
        if (caller == address(0) || !isGuardian(caller)) revert AccessDenied();
        return caller;
    }
}
