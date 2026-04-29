// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { PeerAllowance } from "../peer/Allowance.sol";
import { PeerAssetPull } from "../peer/AssetPull.sol";
import { PeerSettle } from "../peer/Settle.sol";
import { Tx } from "../Cursors.sol";

contract TestPeerHost is Host, PeerAllowance, PeerAssetPull, PeerSettle {
    event PeerAllowanceCalled(uint peer, bytes32 asset, bytes32 meta, uint amount);
    event PeerAssetPullCalled(uint peer, bytes32 asset, bytes32 meta, uint amount);
    event PeerSettleCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);

    constructor(address cmdr) Host(cmdr, 1, "test") {}

    function allowance(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerAllowanceCalled(peer, asset, meta, amount);
    }

    function peerAssetPull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerAssetPullCalled(peer, asset, meta, amount);
    }

    function transfer(Tx memory value) internal override {
        emit PeerSettleCalled(value.from, value.to, value.asset, value.meta, value.amount);
    }

    function getPeerAllowanceId() external view returns (uint) { return peerAllowanceId; }
    function getPeerAssetPullId() external view returns (uint) { return peerAssetPullId; }
    function getPeerSettleId() external view returns (uint) { return peerSettleId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}




