// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { PeerPull } from "../peer/Pull.sol";
import { PeerPush } from "../peer/Push.sol";
import { Block } from "../Blocks.sol";
import { Ids } from "../utils/Ids.sol";

contract TestPeerHost is Host, PeerPull, PeerPush {
    event PeerPullCalled(bytes inputData);
    event PeerPushCalled(bytes inputData);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        PeerPull("")
        PeerPush("")
    {
        if (cmdr != address(0)) access(Ids.toHost(cmdr), true);
    }

    function peerPull(Block memory rawInput) internal override {
        bytes calldata inputData = msg.data[rawInput.i:rawInput.bound];
        emit PeerPullCalled(inputData);
    }

    function peerPush(Block memory rawInput) internal override {
        bytes calldata inputData = msg.data[rawInput.i:rawInput.bound];
        emit PeerPushCalled(inputData);
    }

    function getPeerPullId() external view returns (uint) { return peerPullId; }
    function getPeerPushId() external view returns (uint) { return peerPushId; }
}
