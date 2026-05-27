// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { PeerAllowance } from "../peer/Allowance.sol";
import { PeerBalancePull } from "../peer/BalancePull.sol";
import { PeerPipePayable } from "../peer/Pipe.sol";
import { PeerSettle } from "../peer/Settle.sol";

contract TestPeerHost is Host, PeerAllowance, PeerBalancePull, PeerSettle, PeerPipePayable {
    event PeerAllowanceCalled(uint peer, bytes32 asset, bytes32 meta, uint amount);
    event PeerBalancePullCalled(uint peer, bytes32 asset, bytes32 meta, uint amount);
    event PeerSettleFromCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event PeerSettleToCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event StepDispatched(uint cid, uint stepIndex, uint value);

    uint public stepCount;

    constructor(address cmdr) Host(cmdr, 1, "test") {}

    function allowance(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerAllowanceCalled(peer, asset, meta, amount);
    }

    function balancePull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerBalancePullCalled(peer, asset, meta, amount);
    }

    function settleFrom(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerSettleFromCalled(account, asset, meta, amount);
    }

    function settleTo(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerSettleToCalled(account, asset, meta, amount);
    }

    function dispatch(
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
    function getAdminAccount() external view returns (bytes32) { return admin; }
}




