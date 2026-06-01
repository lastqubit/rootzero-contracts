// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Payable } from "../core/Payable.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";
import { Budget } from "../utils/Value.sol";

using Cursors for Cur;

abstract contract PeerDispatchPayableHook {
    /// @notice Override to dispatch an already encoded payload to `chain`.
    /// @param chain Destination chain node ID.
    /// @param endowment Native value requested for the destination dispatch.
    /// @param payload Encoded payload ready for the transport layer.
    /// @param budget Remaining native-value budget available for dispatch fees.
    function dispatch(uint chain, uint endowment, bytes calldata payload, Budget memory budget) internal virtual;
}

/// @title PeerDispatchPayable
/// @notice Peer endpoint that forwards DISPATCH blocks to a host-defined dispatch hook.
abstract contract PeerDispatchPayable is PeerBase, Payable, PeerDispatchPayableHook {
    string private constant NAME = "peerDispatchPayable";
    uint internal immutable peerDispatchPayableId = peerId(NAME);

    constructor() {
        emit Peer(host, peerDispatchPayableId, NAME, "1:0", Schemas.Dispatch, "", true);
    }

    /// @notice Forward peer-supplied dispatches to the host-defined dispatch hook.
    /// @dev Dispatch hooks receive the shared top-level value budget. Any
    ///      `msg.value` not spent by the hook remains on this host.
    function peerDispatchPayable(bytes calldata request) external payable onlyPeer returns (bytes memory output) {
        (Cur memory input, ) = Cursors.first(request, 1);
        Budget memory budget = valueBudget();

        while (input.i < input.len) {
            (uint chain, uint endowment, bytes calldata payload) = input.unpackDispatch();
            dispatch(chain, endowment, payload, budget);
        }

        input.complete();
        return "";
    }

}
