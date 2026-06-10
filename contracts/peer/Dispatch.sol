// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Payable } from "../core/Payable.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";
import { DispatchPayableHook } from "../commands/Relay.sol";
import { Budget } from "../utils/Value.sol";

using Cursors for Cur;

/// @title PeerDispatchPayable
/// @notice Peer endpoint that forwards DISPATCH blocks to a host-defined dispatch hook.
abstract contract PeerDispatchPayable is PeerBase, Payable, DispatchPayableHook {
    uint internal immutable peerDispatchPayableId = peerId(this.peerDispatchPayable.selector);

    constructor() {
        emit Peer(host, peerDispatchPayableId, "1:0", Schemas.Dispatch, "", true);
        emit Labeled(peerDispatchPayableId, bytes32(0), "peerDispatchPayable");
    }

    /// @notice Forward peer-supplied dispatches to the host-defined dispatch hook.
    /// @dev Dispatch hooks receive the shared top-level source-chain value
    ///      budget. Any `msg.value` not spent by the hook remains on this host.
    /// @param request DISPATCH block stream supplied by the trusted peer.
    /// @return output Empty response bytes.
    function peerDispatchPayable(bytes calldata request) external payable onlyPeer returns (bytes memory output) {
        (Cur memory input, , ) = Cursors.init(request, 1);
        Budget memory budget = valueBudget();

        while (input.i < input.len) {
            (uint chain, uint resources, bytes calldata payload) = input.unpackDispatch();
            dispatch(chain, resources, bytes(payload), budget);
        }

        input.complete();
        return "";
    }

}
