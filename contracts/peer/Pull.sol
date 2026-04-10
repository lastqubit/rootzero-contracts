// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";

string constant NAME = "peerPull";

using Cursors for Cur;

abstract contract PeerPull is PeerBase {
    uint internal immutable peerPullId = peerId(NAME);

    constructor(string memory input) {
        emit Peer(host, NAME, input, peerPullId);
    }

    function peerPull(Cur memory input) internal virtual;

    function peerPull(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, ) = cursor(request, 1);

        while (input.i < input.bound) {
            peerPull(input);
        }

        input.complete();
        return "";
    }
}






