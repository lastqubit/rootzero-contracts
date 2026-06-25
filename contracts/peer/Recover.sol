// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

interface IPeerRecoverContextPayable {
    function peerRecoverContextPayable(bytes calldata request) external payable returns (bytes memory);
}

abstract contract RecoverPayableHook {
    /// @notice Override to recover one incoming context from a peer host.
    /// @dev Implementations may refund, retry, compensate, reconcile, or otherwise
    ///      handle the supplied state and remaining steps.
    /// @param account Account identifier for the recovery context.
    /// @param state Embedded recovery state block stream.
    /// @param steps Embedded recovery step block stream.
    /// @param budget Mutable native-value budget shared across the peer recovery call.
    function recover(bytes32 account, bytes calldata state, bytes calldata steps, Budget memory budget) internal virtual;
}

/// @title PeerRecoverContextPayable
/// @notice Peer endpoint for recovering an interrupted or failed context.
/// @dev Commonly used when a cross-chain context fails at its destination, but the
///      hook is host-defined and may implement any recovery strategy.
abstract contract PeerRecoverContextPayable is PeerBase, Payable, RecoverPayableHook, IPeerRecoverContextPayable {
    uint internal immutable peerRecoverContextPayableId = peerId(this.peerRecoverContextPayable.selector);

    constructor() {
        emit Peer(host, peerRecoverContextPayableId, "1:0", Schemas.Context, "", true);
        emit Labeled(peerRecoverContextPayableId, bytes32(0), "peerRecoverContextPayable");
    }

    /// @notice Forward peer-supplied recovery contexts to the host-defined recovery hook.
    /// @param request CONTEXT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerRecoverContextPayable(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, , ) = Cursors.init(request, 1);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (bytes32 account, bytes calldata state, bytes calldata steps) = input.unpackContext();
            recover(account, state, steps, budget);
        }

        input.complete();
        return "";
    }
}
