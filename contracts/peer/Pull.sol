// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cursor } from "../Cursors.sol";

string constant NAME = "peerPull";

abstract contract PeerPull is PeerBase {
    uint internal immutable peerPullId = peerId(NAME);

    constructor(string memory input) {
        emit Peer(host, NAME, input, peerPullId);
    }

    function peerPull(Cursor memory input) internal virtual;

    function peerPull(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            Cursor memory input = Cursors.openBlock(request, q);
            peerPull(input);
            q = input.next;
        }

        return done(0, q);
    }
}





