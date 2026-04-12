// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { OperationBase } from "../core/Operation.sol";
import { PeerEvent } from "../events/Peer.sol";
import { Ids, Selectors } from "../utils/Ids.sol";

/// @title PeerBase
/// @notice Abstract base for all rootzero peer contracts.
/// Peers handle inter-host asset flows (push/pull) and asset allow/deny management
/// between cooperating hosts. Access is restricted to trusted callers via `onlyPeer`.
abstract contract PeerBase is OperationBase, PeerEvent {
    /// @dev Restrict execution to trusted callers (authorized hosts or the commander).
    modifier onlyPeer() {
        enforceCaller(msg.sender);
        _;
    }

    /// @notice Derive the deterministic node ID for a named peer on this contract.
    /// @param name Peer function name (without argument list).
    /// @return Peer node ID.
    function peerId(string memory name) internal view returns (uint) {
        return Ids.toPeer(Selectors.peer(name), address(this));
    }
}
