// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { PeerAssetPull } from "../peer/AssetPull.sol";
import { PeerPull } from "../peer/Pull.sol";
import { PeerPush } from "../peer/Push.sol";
import { PeerSettle } from "../peer/Settle.sol";
import { Cursors, Cur, Keys, Tx } from "../Cursors.sol";
import { Ids } from "../utils/Ids.sol";

using Cursors for Cur;

contract TestPeerHost is Host, PeerAssetPull, PeerPull, PeerPush, PeerSettle {
    event PeerAssetPullCalled(uint peer, bytes32 asset, bytes32 meta, uint amount);
    event PeerPullCalled(uint peer, bytes inputData);
    event PeerPushCalled(uint peer, bytes inputData);
    event PeerSettleCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        PeerPull("")
        PeerPush("")
    {
        if (cmdr != address(0)) access(Ids.toHost(cmdr), true);
    }

    function peerAssetPull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerAssetPullCalled(peer, asset, meta, amount);
    }

    function peerPull(uint peer, Cur memory input) internal override {
        (bytes4 key, uint len) = input.peek(input.i);
        uint next = input.i + 8 + len;
        bytes calldata inputData = key == Keys.Route
            ? input.unpackRoute()
            : msg.data[input.offset + input.i:input.offset + next];
        input.i = next;
        emit PeerPullCalled(peer, inputData);
    }

    function peerPush(uint peer, Cur memory input) internal override {
        (bytes4 key, uint len) = input.peek(input.i);
        uint next = input.i + 8 + len;
        bytes calldata inputData = key == Keys.Route
            ? input.unpackRoute()
            : msg.data[input.offset + input.i:input.offset + next];
        input.i = next;
        emit PeerPushCalled(peer, inputData);
    }

    function transfer(Tx memory value) internal override {
        emit PeerSettleCalled(value.from, value.to, value.asset, value.meta, value.amount);
    }

    function getPeerAssetPullId() external view returns (uint) { return peerAssetPullId; }
    function getPeerPullId() external view returns (uint) { return peerPullId; }
    function getPeerPushId() external view returns (uint) { return peerPushId; }
    function getPeerSettleId() external view returns (uint) { return peerSettleId; }
}




