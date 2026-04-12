// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";

string constant NAME = "peerPush";

using Cursors for Cur;

/// @title PeerPush
/// @notice Peer that receives assets pushed from a remote host into this one.
/// Each block in the request is dispatched to `peerPush(Cur)`. Restricted to trusted peers.
abstract contract PeerPush is PeerBase {
    uint internal immutable peerPushId = peerId(NAME);

    constructor(string memory input) {
        emit Peer(host, NAME, input, peerPushId);
    }

    /// @notice Override to process a single incoming block from the push request.
    /// @param input Cursor positioned at the current input block; advance it before returning.
    function peerPush(Cur memory input) internal virtual;

    /// @notice Execute the push peer call.
    function peerPush(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, , ) = cursor(request, 1);

        while (input.i < input.bound) {
            peerPush(input);
        }

        input.complete();
        return "";
    }
}






