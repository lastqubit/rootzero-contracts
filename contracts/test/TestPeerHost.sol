// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {PeerPull} from "../peer/Pull.sol";
import {PeerPush} from "../peer/Push.sol";
import {DataRef} from "../blocks/Schema.sol";
import {toHostId} from "../utils/Ids.sol";

contract TestPeerHost is Host, PeerPull, PeerPush {
    event PeerPullCalled(bytes routeData);
    event PeerPushCalled(bytes routeData);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        PeerPull("")
        PeerPush("")
    {
        if (cmdr != address(0)) access(toHostId(cmdr), true);
    }

    function peerPull(DataRef memory rawRoute) internal override {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit PeerPullCalled(routeData);
    }

    function peerPush(DataRef memory rawRoute) internal override {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit PeerPushCalled(routeData);
    }

    function getPeerPullId() external view returns (uint) { return peerPullId; }
    function getPeerPushId() external view returns (uint) { return peerPushId; }
}
