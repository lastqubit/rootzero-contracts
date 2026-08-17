// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Allocate } from "../commands/Allocate.sol";
import { Deposit, DepositPayable } from "../commands/Deposit.sol";
import { Withdraw } from "../commands/Withdraw.sol";
import { CreditAccountInternal } from "../commands/Credit.sol";
import { DebitAccountInternal } from "../commands/Debit.sol";
import { Payout } from "../commands/Payout.sol";
import { Provision, ProvisionPayable } from "../commands/Provision.sol";
import { RelayPayable, RelayBalancePayable } from "../commands/Relay.sol";
import { RecoverPayable } from "../commands/Recover.sol";
import { Repay, RepayPayable } from "../commands/Repay.sol";
import { SettleInternal, SettlePayable } from "../commands/Settle.sol";
import { Pipeline } from "../core/Pipeline.sol";
import { Settlement, SettleHook } from "../core/Settlement.sol";
import { PostPort } from "../ports/Post.sol";
import { AllowAssets } from "../commands/admin/AllowAssets.sol";
import { DenyAssets } from "../commands/admin/DenyAssets.sol";
import { Allowance } from "../commands/admin/Allowance.sol";
import { RevokeAllowance, RevokeAsset } from "../guards/Revoke.sol";
import { HostAmount } from "../core/Types.sol";
import { Reader, Readers } from "../Codec.sol";
import { Execution, Executions } from "../execution/Execution.sol";
import {Budget, Budgets} from "../execution/Budget.sol";

using Readers for Reader;
using Executions for Execution;
using Budgets for Budget;

contract TestHost is
    Host,
    Allocate,
    Deposit,
    DepositPayable,
    Withdraw,
    CreditAccountInternal,
    DebitAccountInternal,
    Payout,
    Provision,
    ProvisionPayable,
    RelayPayable,
    RelayBalancePayable,
    RecoverPayable,
    Repay,
    RepayPayable,
    SettleInternal,
    SettlePayable,
    Settlement,
    Pipeline,
    PostPort,
    AllowAssets,
    DenyAssets,
    Allowance,
    RevokeAllowance,
    RevokeAsset
{
    event AllocateCalled(uint host_, bytes32 account, bytes32 asset, uint amount);
    event DepositCalled(bytes32 account, bytes32 asset, uint amount);
    event DepositPayableCalled(bytes32 account, bytes32 asset, uint amount, uint remaining);
    event WithdrawCalled(bytes32 account, bytes32 asset, uint amount);
    event CreditToCalled(bytes32 account, bytes32 asset, uint amount, uint returned);
    event DebitFromCalled(bytes32 account, bytes32 asset, uint amount, uint returned);
    event PayoutCalled(bytes32 account, bytes32 to, bytes32 asset, uint amount);
    event ProvisionCalled(uint host_, bytes32 account, bytes32 asset, uint amount);
    event ProvisionPayableCalled(uint host_, bytes32 account, bytes32 asset, uint amount, uint remaining);
    event RelayCalled(uint portal, uint resources, bytes32 account, bytes state, bytes input);
    event RecoverCalled(uint handler, uint resources, bytes32 key, bytes witness, uint128 value);
    event SettleCalled(
        bytes32 account,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt
    );
    event SettlePayableCalled(
        bytes32 account,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt,
        uint remaining
    );
    event RepayPayableCalled(
        bytes32 account,
        bytes32 liability,
        uint debt,
        uint remaining
    );
    event AllowAssetCalled(bytes32 asset);
    event DenyAssetCalled(bytes32 asset);
    event AllowanceCalled(uint host_, bytes32 asset, uint amount);
    event StepDispatched(uint cid, uint stepIndex, uint128 value);

    uint public stepCount;

    constructor(address rootzero) Host(rootzero) Allocate() Deposit() Provision() {}

    function allocate(bytes32 account, HostAmount memory custody) internal override {
        emit AllocateCalled(custody.host, account, custody.asset, custody.amount);
    }

    function deposit(bytes32 account, bytes32 asset, uint amount) internal override {
        emit DepositCalled(account, asset, amount);
    }

    function deposit(
        bytes32 account,
        bytes32 asset,
        uint amount,
        Execution memory funds
    ) internal override {
        emit DepositPayableCalled(account, asset, funds.useValue(amount), funds.budget);
    }

    function withdraw(bytes32 account, bytes32 asset, uint amount) internal override {
        emit WithdrawCalled(account, asset, amount);
    }

    function settle(
        bytes32 account,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt
    ) internal override(Settlement, SettleHook) {
        emit SettleCalled(account, asset, amount, liability, debt);
    }

    function settle(
        bytes32 account,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt,
        Execution memory funds
    ) internal override {
        funds.useValue(amount + debt);
        emit SettlePayableCalled(account, asset, amount, liability, debt, funds.budget);
    }

    function repay(
        bytes32 account,
        bytes32 liability,
        uint debt,
        Execution memory funds
    ) internal override {
        funds.useValue(debt);
        emit RepayPayableCalled(account, liability, debt, funds.budget);
    }

    function creditAccount(bytes32 account, bytes32 asset, uint amount) internal override {
        emit CreditToCalled(account, asset, amount, amount);
    }

    function debitAccount(bytes32 account, bytes32 asset, uint amount) internal override {
        emit DebitFromCalled(account, asset, amount, amount);
    }

    function payout(bytes32 account, bytes32 to, bytes32 asset, uint amount) internal override {
        emit PayoutCalled(account, to, asset, amount);
    }

    function provision(bytes32 account, HostAmount memory custody) internal override {
        emit ProvisionCalled(custody.host, account, custody.asset, custody.amount);
    }

    function provision(
        bytes32 account,
        HostAmount memory custody,
        Execution memory funds
    ) internal override {
        emit ProvisionPayableCalled(
            custody.host, account, custody.asset, funds.useValue(custody.amount), funds.budget
        );
    }

    function relay(
        uint portal,
        uint resources,
        bytes32 account,
        bytes calldata state,
        bytes calldata input,
        Execution memory funds
    ) internal override {
        funds;
        emit RelayCalled(portal, resources, account, state, input);
    }

    function recover(
        uint handler,
        uint resources,
        bytes32 key,
        bytes calldata witness,
        Execution memory funds
    ) internal override {
        emit RecoverCalled(handler, resources, key, witness, funds.useResourceValue(resources));
    }

    function allowAsset(bytes32 asset) internal override {
        emit AllowAssetCalled(asset);
    }

    function denyAsset(bytes32 asset) internal override {
        emit DenyAssetCalled(asset);
    }

    function allowance(uint peer, bytes32 asset, uint amount) internal override {
        emit AllowanceCalled(peer, asset, amount);
    }

    function dispatch(
        uint cid,
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint128 value
    ) internal override returns (bytes memory nextState, bytes memory transactions) {
        emit StepDispatched(cid, stepCount++, value);
        if (cid == debitAccountId()) {
            return executeDebitAccount(account, state, input, value);
        }
        if (cid == creditAccountId()) {
            return executeCreditAccount(account, state, input, value);
        }
        if (cid == settleId()) {
            return executeSettle(account, state, input, value);
        }
        if (cid == type(uint).max) return (state, input);
        return (state, "");
    }

    function testPipe(bytes32 account, bytes memory state, bytes calldata steps) external payable {
        Execution memory exec = Executions.open();
        Budget memory budget = exec.takeBudget();
        pipe(account, state, steps, budget);
        exec.budget = budget.drain();
        Reader memory txs;
        (, txs.source) = close(exec, account);
        while (txs.more()) {
            (bytes32 from, bytes32 to, bytes32 asset, uint amount) = txs.unpackTransaction();
            post(from, to, asset, amount);
        }
    }

    function getAdminAccount() external view returns (bytes32) {
        return admin;
    }

    function getCommander() external view returns (address) {
        return commander;
    }

    function isAuthorized(uint node) external view returns (bool) {
        return nodes[node];
    }

    function testAuthorizeId() external view returns (uint) {
        return authorizeId();
    }

    function testUnauthorizeId() external view returns (uint) {
        return unauthorizeId();
    }

    function setGuardianAccount(bytes32 account, bool active) external {
        setGuardian(account, active);
    }

    function isGuardianAddress(address addr) external view returns (bool) {
        return isGuardian(addr);
    }

}




