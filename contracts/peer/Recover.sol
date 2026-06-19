// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

interface IPeerRecover {
    function peerRecover(bytes calldata request) external returns (bytes memory);
}

abstract contract RecoverHook {
    /// @notice Override to recover one incoming pipe context from a peer host.
    /// @dev Implementations may refund, retry, compensate, reconcile, or otherwise
    ///      handle the supplied state and remaining steps.
    /// @param account Account identifier for the recovery context.
    /// @param state Embedded recovery state block stream.
    /// @param steps Embedded recovery step block stream.
    function recover(bytes32 account, bytes calldata state, bytes calldata steps) internal virtual;
}

/// @title PeerRecover
/// @notice Peer endpoint for recovering an interrupted or failed pipe context.
/// @dev Commonly used when a cross-chain pipe fails at its destination, but the
///      hook is host-defined and may implement any recovery strategy. Each PIPE
///      block carries chain resources plus a CONTEXT block; the nested context
///      is passed to the recovery hook and resources are not allocated.
abstract contract PeerRecover is PeerBase, RecoverHook, IPeerRecover {
    uint internal immutable peerRecoverId = peerId(this.peerRecover.selector);

    constructor() {
        emit Peer(host, peerRecoverId, "1:0", Schemas.Pipe, "", false);
        emit Labeled(peerRecoverId, bytes32(0), "peerRecover");
    }

    /// @notice Forward peer-supplied recovery pipes to the host-defined recovery hook.
    /// @param request PIPE block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerRecover(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory input, , ) = Cursors.init(request, 1);

        while (input.i < input.len) {
            (, bytes32 account, bytes calldata state, bytes calldata steps) = input.unpackPipe();
            recover(account, state, steps);
        }

        input.complete();
        return "";
    }
}
