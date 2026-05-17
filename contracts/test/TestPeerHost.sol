// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { PeerAllowance } from "../peer/Allowance.sol";
import { PeerBalancePull } from "../peer/BalancePull.sol";
import { PeerPipePayable, PeerStagePayable } from "../peer/Pipe.sol";
import { PeerSettle } from "../peer/Settle.sol";
import { Tx } from "../Cursors.sol";

contract TestPeerHost is Host, PeerAllowance, PeerBalancePull, PeerSettle, PeerPipePayable, PeerStagePayable {
    event PeerAllowanceCalled(uint peer, bytes32 asset, bytes32 meta, uint amount);
    event PeerBalancePullCalled(uint peer, bytes32 asset, bytes32 meta, uint amount);
    event PeerSettleCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);
    event StepDispatched(uint cid, uint stepIndex, uint value);

    uint public stepCount;

    constructor(address cmdr) Host(cmdr, 1, "test") {}

    function allowance(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerAllowanceCalled(peer, asset, meta, amount);
    }

    function balancePull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerBalancePullCalled(peer, asset, meta, amount);
    }

    function transfer(Tx memory value) internal override {
        emit PeerSettleCalled(value.from, value.to, value.asset, value.meta, value.amount);
    }

    function dispatchCommand(
        uint cid,
        bytes32,
        bytes memory state,
        bytes calldata,
        uint value
    ) internal override returns (bytes memory) {
        emit StepDispatched(cid, stepCount++, value);
        return state;
    }

    function getPeerAllowanceId() external view returns (uint) { return peerAllowanceId; }
    function getPeerBalancePullId() external view returns (uint) { return peerBalancePullId; }
    function getPeerSettleId() external view returns (uint) { return peerSettleId; }
    function getPeerPipePayableId() external view returns (uint) { return peerPipePayableId; }
    function getPeerStagePayableId() external view returns (uint) { return peerStagePayableId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}




