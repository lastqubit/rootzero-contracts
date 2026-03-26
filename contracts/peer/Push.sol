// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "peerPush";

abstract contract PeerPush is PeerBase {
    uint internal immutable peerPushId = peerId(NAME);

    constructor(string memory route) {
        emit Peer(host, NAME, route, peerPushId);
    }

    function peerPush(Block memory rawRoute) internal virtual;

    function peerPush(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            Block memory ref = Blocks.from(request, q);
            if (ref.key != Keys.Route) break;
            peerPush(ref);
            q = ref.cursor;
        }

        return done(0, q);
    }
}
