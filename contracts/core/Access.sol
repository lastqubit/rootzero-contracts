// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AccessEvent } from "../events/Access.sol";
import { Accounts } from "../utils/Accounts.sol";
import { Ids } from "../utils/Ids.sol";
import { addrOr } from "../utils/Utils.sol";

/// @title AccessControl
/// @notice Host access control layer.
/// Tracks an immutable trusted commander, the host's own node ID, and a
/// mapping of externally authorized node IDs. Inbound trust is host-based:
/// authorized hosts, the commander, and this contract itself may interact
/// with the host through the guarded command and peer entrypoints.
abstract contract AccessControl is AccessEvent {
    /// @dev Trusted commander address. All calls from this address are implicitly trusted.
    /// Defaults to `address(this)` when no external commander is provided.
    address internal immutable commander;
    /// @dev Admin account ID derived from the commander address at construction time.
    bytes32 internal immutable adminAccount;
    /// @dev This host's node ID, set to `Ids.toHost(address(this))` at construction.
    uint public immutable host;

    /// @dev Mapping from node ID to authorization status.
    /// Authorised nodes may interact with the host as trusted callers or call targets.
    mapping(uint => bool) internal authorized;

    /// @dev Thrown when `ensureTrusted` is called with a node that is not authorized.
    error UnauthorizedNode(uint node);
    /// @dev Thrown when `enforceCaller` is called by an address that is not trusted.
    error UnauthorizedCaller(address addr);

    constructor(address cmdr) {
        commander = addrOr(cmdr, address(this));
        adminAccount = Accounts.toAdmin(commander);
        host = Ids.toHost(address(this));
    }

    /// @notice Grant or revoke authorization for a node.
    /// Inbound authentication is host-based: the node ID used here should be a host ID.
    /// @param node Node ID to authorize or deauthorize.
    /// @param allow True to grant authorization, false to revoke it.
    function access(uint node, bool allow) internal {
        authorized[node] = allow;
        emit Access(host, node, allow);
    }

    /// @notice Return true if `caller` is an implicitly trusted address.
    /// Trusted callers: the commander, this contract itself, or any address
    /// whose host ID has been explicitly authorized.
    /// @param caller Address to check.
    function isTrusted(address caller) internal view returns (bool) {
        return caller == commander || caller == address(this) || authorized[Ids.toHost(caller)];
    }

    /// @notice Assert that `caller` is trusted and return it.
    /// Used by command and peer modifiers to gate execution to authorized senders.
    /// @param caller Address to validate.
    /// @return The same `caller` value if trusted.
    function enforceCaller(address caller) internal view returns (address) {
        if (caller == address(0) || !isTrusted(caller)) {
            revert UnauthorizedCaller(caller);
        }
        return caller;
    }

    /// @notice Assert that `node` is in the authorized set and return it.
    /// Used for outbound trust checks before calling another node.
    /// Accepts any authorized node ID (host or command).
    /// Inbound caller authentication is host-only via `enforceCaller(msg.sender)`.
    /// @param node Node ID to validate.
    /// @return The same `node` value if authorized.
    function ensureTrusted(uint node) internal view returns (uint) {
        if (node == 0 || !authorized[node]) {
            revert UnauthorizedNode(node);
        }
        return node;
    }
}
