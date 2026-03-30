// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Blocks, Block } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "peerPush";

abstract contract PeerPush is PeerBase {
    uint internal immutable peerPushId = peerId(NAME);

    constructor(string memory input) {
        emit Peer(host, NAME, input, peerPushId);
    }

    function peerPush(Block memory rawInput) internal virtual;

    function peerPush(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            Block memory input = Blocks.from(request, q);
            peerPush(input);
            q = input.cursor;
        }

        return done(0, q);
    }
}
