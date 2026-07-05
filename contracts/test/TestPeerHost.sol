// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { PortAllowance } from "../ports/Allowance.sol";
import { PortRedeemBalance } from "../ports/Redeem.sol";
import { PortCreditAccount } from "../ports/Credit.sol";
import { PortDebitAccount } from "../ports/Debit.sol";
import { PortPipePayable } from "../ports/Pipe.sol";
import { PortDispatchPayable } from "../ports/Dispatch.sol";
import { PortSettle } from "../ports/Settle.sol";
import { Budget } from "../utils/Value.sol";

contract TestPortHost is Host, PortAllowance, PortRedeemBalance, PortCreditAccount, PortDebitAccount, PortSettle, PortPipePayable, PortDispatchPayable {
    event PortAllowanceCalled(uint peer, bytes32 asset, uint amount);
    event PortRedeemBalanceCalled(uint peer, bytes32 asset, uint amount);
    event PortDebitAccountCalled(bytes32 account, bytes32 asset, uint amount);
    event PortCreditAccountCalled(bytes32 account, bytes32 asset, uint amount);
    event PortDispatchCalled(uint portal, bytes payload, uint resources, uint remaining);
    event StepDispatched(uint cid, uint stepIndex, uint128 value);

    uint public stepCount;

    constructor(address cmdr) Host(cmdr) {}

    function allowance(uint peer, bytes32 asset, uint amount) internal override {
        emit PortAllowanceCalled(peer, asset, amount);
    }

    function redeemBalance(uint peer, bytes32 asset, uint amount) internal override {
        emit PortRedeemBalanceCalled(peer, asset, amount);
    }

    function debitAccount(bytes32 account, bytes32 asset, uint amount) internal override {
        emit PortDebitAccountCalled(account, asset, amount);
    }

    function creditAccount(bytes32 account, bytes32 asset, uint amount) internal override {
        emit PortCreditAccountCalled(account, asset, amount);
    }

    function route(uint portal, uint resources, bytes memory payload, Budget memory budget) internal override {
        emit PortDispatchCalled(portal, payload, resources, budget.remaining);
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

    function getPortAllowanceId() external view returns (uint) { return portAllowanceId; }
    function getPortRedeemBalanceId() external view returns (uint) { return portRedeemBalanceId; }
    function getPortCreditAccountId() external view returns (uint) { return portCreditAccountId; }
    function getPortDebitAccountId() external view returns (uint) { return portDebitAccountId; }
    function getPortSettleId() external view returns (uint) { return portSettleId; }
    function getPortPipePayableId() external view returns (uint) { return portPipePayableId; }
    function getPortDispatchPayableId() external view returns (uint) { return portDispatchPayableId; }
    function getAdminAccount() external view returns (bytes32) { return admin; }
}




