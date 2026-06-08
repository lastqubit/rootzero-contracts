// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { NodeCalls } from "../core/Calls.sol";
import { PeerEvent } from "../events/Peer.sol";
import { LabeledEvent } from "../events/Labeled.sol";
import { Ids } from "../utils/Ids.sol";

/// @notice ABI-encode a peer call from a target peer ID and request block stream.
/// @dev Derives the function selector from `target` via `Ids.peerSelector(target)`.
/// Reverts if `target` is not a valid peer ID.
/// @param target Destination peer node ID embedding the target selector.
/// @param request Input block stream for the peer invocation.
/// @return ABI-encoded calldata for the peer entry point.
function encodePeerCall(uint target, bytes calldata request) pure returns (bytes memory) {
    bytes4 selector = Ids.peerSelector(target);
    return abi.encodeWithSelector(selector, request);
}

/// @title PeerBase
/// @notice Abstract base for all rootzero peer contracts.
/// Peers handle inter-host operations and asset allow/deny management
/// between cooperating hosts. Access is restricted to trusted callers via `onlyPeer`.
abstract contract PeerBase is NodeCalls, PeerEvent, LabeledEvent {
    /// @dev Thrown when the commander attempts to call a peer entrypoint directly.
    error CommanderNotAllowed();

    /// @dev Restrict execution to trusted callers, excluding the commander.
    modifier onlyPeer() {
        if (msg.sender == commander) revert CommanderNotAllowed();
        enforceCaller(msg.sender);
        _;
    }

    /// @notice Derive the deterministic node ID for a peer selector on this contract.
    /// @param selector Peer entrypoint selector.
    /// @return Peer node ID.
    function peerId(bytes4 selector) internal view returns (uint) {
        return Ids.toPeer(selector, address(this));
    }
}
