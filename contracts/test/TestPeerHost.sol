// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { PortAllowance } from "../ports/Allowance.sol";
import { PortRedeemBalance } from "../ports/Redeem.sol";
import { PortCreditAccount } from "../ports/Credit.sol";
import { PortDebitAccount } from "../ports/Debit.sol";
import { PortPipePayable } from "../ports/Pipe.sol";
import { PortDispatchPayable } from "../ports/Dispatch.sol";
import { PortPost } from "../ports/Post.sol";
import { Settlement } from "../core/Settlement.sol";
import { Position } from "../core/Types.sol";
import { Execution } from "../execution/Execution.sol";

contract TestPortHost is Host, Settlement, PortAllowance, PortRedeemBalance, PortCreditAccount, PortDebitAccount, PortPost, PortPipePayable, PortDispatchPayable {
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

    function testSettle(bytes32 account, Position calldata position) external {
        settle(account, position.asset, position.amount, position.liability, position.debt);
    }

    function relayTo(uint portal, uint resources, bytes memory payload, Execution memory funds) internal override {
        emit PortDispatchCalled(portal, payload, resources, funds.budget);
    }

    function dispatch(
        uint cid,
        bytes32,
        bytes memory state,
        bytes calldata,
        uint128 value
    ) internal override returns (bytes memory nextState, bytes memory transactions) {
        emit StepDispatched(cid, stepCount++, value);
        return (state, "");
    }

    function getAdminAccount() external view returns (bytes32) { return admin; }
}




