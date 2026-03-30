// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Blocks, Block } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "peerPull";

abstract contract PeerPull is PeerBase {
    uint internal immutable peerPullId = peerId(NAME);

    constructor(string memory input) {
        emit Peer(host, NAME, input, peerPullId);
    }

    function peerPull(Block memory rawInput) internal virtual;

    function peerPull(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            Block memory input = Blocks.from(request, q);
            peerPull(input);
            q = input.cursor;
        }

        return done(0, q);
    }
}
