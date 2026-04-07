// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cursor } from "../Cursors.sol";

string constant NAME = "peerPush";

using Cursors for Cursor;

abstract contract PeerPush is PeerBase {
    uint internal immutable peerPushId = peerId(NAME);

    constructor(string memory input) {
        emit Peer(host, NAME, input, peerPushId);
    }

    function peerPush(Cursor memory input) internal virtual;

    function peerPush(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        Cursor memory inputs = Cursors.openInput(request, 0, 1);
        while (inputs.i < inputs.end) {
            peerPush(inputs.take());
        }
        return inputs.complete();
    }
}





