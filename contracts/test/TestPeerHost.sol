// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { PeerAllowance } from "../peer/Allowance.sol";
import { PeerRedeemBalance } from "../peer/Redeem.sol";
import { PeerCreditAccount } from "../peer/Credit.sol";
import { PeerDebitAccount } from "../peer/Debit.sol";
import { PeerPipePayable } from "../peer/Pipe.sol";
import { PeerRecover } from "../peer/Recover.sol";
import { PeerDispatchPayable } from "../peer/Dispatch.sol";
import { PeerSettle } from "../peer/Settle.sol";
import { Budget } from "../utils/Value.sol";

contract TestPeerHost is Host, PeerAllowance, PeerRedeemBalance, PeerCreditAccount, PeerDebitAccount, PeerSettle, PeerPipePayable, PeerRecover, PeerDispatchPayable {
    event PeerAllowanceCalled(uint peer, bytes32 asset, uint amount);
    event PeerRedeemBalanceCalled(uint peer, bytes32 asset, uint amount);
    event PeerDebitAccountCalled(bytes32 account, bytes32 asset, uint amount);
    event PeerCreditAccountCalled(bytes32 account, bytes32 asset, uint amount);
    event PeerDispatchCalled(uint chain, bytes payload, uint resources, uint remaining);
    event PeerRecoverCalled(bytes32 account, bytes state, bytes steps);
    event StepDispatched(uint cid, uint stepIndex, uint128 value);

    uint public stepCount;

    constructor(address cmdr) Host(cmdr) {}

    function allowance(uint peer, bytes32 asset, uint amount) internal override {
        emit PeerAllowanceCalled(peer, asset, amount);
    }

    function redeemBalance(uint peer, bytes32 asset, uint amount) internal override {
        emit PeerRedeemBalanceCalled(peer, asset, amount);
    }

    function debitAccount(bytes32 account, bytes32 asset, uint amount) internal override {
        emit PeerDebitAccountCalled(account, asset, amount);
    }

    function creditAccount(bytes32 account, bytes32 asset, uint amount) internal override {
        emit PeerCreditAccountCalled(account, asset, amount);
    }

    function dispatch(uint chain, uint resources, bytes memory payload, Budget memory budget) internal override {
        emit PeerDispatchCalled(chain, payload, resources, budget.remaining);
    }

    function recover(
        bytes32 account,
        bytes calldata state,
        bytes calldata steps
    ) internal override {
        emit PeerRecoverCalled(account, state, steps);
    }

    function dispatch(
        uint cid,
        bytes32,
        bytes memory state,
        bytes calldata,
        uint128 value
    ) internal override returns (bytes memory) {
        emit StepDispatched(cid, stepCount++, value);
        return state;
    }

    function getPeerAllowanceId() external view returns (uint) { return peerAllowanceId; }
    function getPeerRedeemBalanceId() external view returns (uint) { return peerRedeemBalanceId; }
    function getPeerCreditAccountId() external view returns (uint) { return peerCreditAccountId; }
    function getPeerDebitAccountId() external view returns (uint) { return peerDebitAccountId; }
    function getPeerSettleId() external view returns (uint) { return peerSettleId; }
    function getPeerPipePayableId() external view returns (uint) { return peerPipePayableId; }
    function getPeerRecoverId() external view returns (uint) { return peerRecoverId; }
    function getPeerDispatchPayableId() external view returns (uint) { return peerDispatchPayableId; }
    function getAdminAccount() external view returns (bytes32) { return admin; }
}




