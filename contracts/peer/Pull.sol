// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "peerPull";

abstract contract PeerPull is PeerBase {
    uint internal immutable peerPullId = peerId(NAME);

    constructor(string memory route) {
        emit Peer(host, NAME, route, peerPullId);
    }

    function peerPull(Block memory rawRoute) internal virtual;

    function peerPull(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            Block memory ref = Blocks.from(request, q);
            if (ref.key != Keys.Route) break;
            peerPull(ref);
            q = ref.cursor;
        }

        return done(0, q);
    }
}
