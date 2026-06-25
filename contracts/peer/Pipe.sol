// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Pipeline} from "../core/Pipeline.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

interface IPeerPipePayable {
    function peerPipePayable(bytes calldata request) external payable returns (bytes memory);
}

/// @title PeerPipePayable
/// @notice Peer that consumes CONTEXT blocks and executes each request as a step stream.
/// Each context's request bytes are passed to the shared pipeline as the steps.
abstract contract PeerPipePayable is PeerBase, Pipeline, IPeerPipePayable {
    uint internal immutable peerPipePayableId = peerId(this.peerPipePayable.selector);

    constructor() {
        emit Peer(host, peerPipePayableId, "1:0", Schemas.Context, "", true);
        emit Labeled(peerPipePayableId, bytes32(0), "peerPipePayable");
    }

    /// @notice Execute peer-supplied contexts through the shared payable pipe.
    /// @dev All contexts share the peer call's native-value budget. Any unspent
    ///      `msg.value` remains on this host.
    /// @param request CONTEXT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerPipePayable(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, , ) = Cursors.init(request, 1);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (bytes32 account, bytes calldata state, bytes calldata steps) = input.unpackContext();
            pipe(account, state, steps, budget);
        }

        input.complete();
        return "";
    }
}
