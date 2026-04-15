// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";

string constant NAME = "peerPull";

using Cursors for Cur;

/// @title PeerPull
/// @notice Peer that pulls assets from a remote host into this one.
/// Each block in the request is dispatched to `peerPull(Cur)`. Restricted to trusted peers.
abstract contract PeerPull is PeerBase {
    uint internal immutable peerPullId = peerId(NAME);

    constructor(string memory input) {
        emit Peer(host, NAME, input, peerPullId, false);
    }

    /// @notice Override to process a single incoming block from the pull request.
    /// @param input Cursor positioned at the current input block; advance it before returning.
    function peerPull(Cur memory input) internal virtual;

    /// @notice Execute the pull peer call.
    function peerPull(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory input, , ) = cursor(request, 1);

        while (input.i < input.bound) {
            peerPull(input);
        }

        input.complete();
        return "";
    }
}






