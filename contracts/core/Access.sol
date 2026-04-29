// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessEvent} from "../events/Access.sol";
import {RootZeroContext} from "./Context.sol";
import {Accounts} from "../utils/Accounts.sol";
import {Ids} from "../utils/Ids.sol";
import {addrOr} from "../utils/Utils.sol";

/// @title AccessControl
/// @notice Host access control layer.
/// Tracks an immutable trusted commander, the host's own node ID, and a
/// mapping of externally trusted node IDs. Inbound trust is host-based:
/// trusted hosts, the commander, and this contract itself may interact
/// with the host through the guarded command and peer entrypoints.
abstract contract AccessControl is RootZeroContext, AccessEvent {
    /// @dev Trusted commander address. All calls from this address are implicitly trusted.
    /// Defaults to `address(this)` when no external commander is provided.
    address internal immutable commander;
    /// @dev Admin account ID derived from the commander address at construction time.
    bytes32 internal immutable adminAccount;

    /// @dev Mapping from node ID to trust status.
    mapping(uint node => bool) internal trusted;

    /// @dev Thrown when `enforceCaller` is called by an address that is not trusted.
    error UnauthorizedCaller(address addr);

    /// @dev Thrown when a required trusted node is missing from the trusted set.
    error UnauthorizedNode(uint node);

    constructor(address cmdr) {
        commander = addrOr(cmdr, address(this));
        adminAccount = Accounts.toAdmin(commander);
    }

    /// @notice Grant authorization for a node.
    /// Accepts any node ID that should be trusted by this contract.
    /// @param node Node ID to authorize.
    function authorize(uint node) internal {
        trusted[node] = true;
        emit Access(host, node, true);
    }

    /// @notice Revoke authorization for a node.
    /// Accepts any node ID that should no longer be trusted by this contract.
    /// @param node Node ID to unauthorize.
    function unauthorize(uint node) internal {
        trusted[node] = false;
        emit Access(host, node, false);
    }

    /// @notice Return true if `caller` is an implicitly trusted address.
    /// Trusted callers: the commander, this contract itself, or any address
    /// whose host ID has been explicitly authorized.
    /// @param caller Address to check.
    function isTrusted(address caller) internal view returns (bool) {
        return caller == commander || caller == address(this) || trusted[Ids.toHost(caller)];
    }

    /// @notice Assert that `node` is in the trusted set and return it.
    /// @param node Node ID to validate.
    /// @return The same `node` value if trusted.
    function ensureTrusted(uint node) internal view returns (uint) {
        if (node == 0 || !trusted[node]) {
            revert UnauthorizedNode(node);
        }
        return node;
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
}
