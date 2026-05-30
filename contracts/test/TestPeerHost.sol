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
    event PeerDebitAccountCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event PeerCreditAccountCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event StepDispatched(uint cid, uint stepIndex, uint value);

    uint public stepCount;

    constructor(address cmdr) Host(cmdr, 1, "test") {}

    function allowance(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerAllowanceCalled(peer, asset, meta, amount);
    }

    function balancePull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerBalancePullCalled(peer, asset, meta, amount);
    }

    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerDebitAccountCalled(account, asset, meta, amount);
    }

    function creditAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PeerCreditAccountCalled(account, asset, meta, amount);
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




