// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cursor } from "../Cursors.sol";

string constant NAME = "peerPull";

using Cursors for Cursor;

abstract contract PeerPull is PeerBase {
    uint internal immutable peerPullId = peerId(NAME);

    constructor(string memory input) {
        emit Peer(host, NAME, input, peerPullId);
    }

    function peerPull(Cursor memory input) internal virtual;

    function peerPull(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        Cursor memory inputs = Cursors.openInput(request, 0, 1);
        while (inputs.i < inputs.end) {
            peerPull(inputs.take());
        }
        return inputs.complete();
    }
}





