// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Allocate } from "../commands/Allocate.sol";
import { Deposit, DepositPayable } from "../commands/Deposit.sol";
import { Withdraw } from "../commands/Withdraw.sol";
import { CreditAccount } from "../commands/Credit.sol";
import { DebitAccount } from "../commands/Debit.sol";
import { Payout } from "../commands/Payout.sol";
import { Provision, ProvisionPayable } from "../commands/Provision.sol";
import { RelayPayable } from "../commands/Relay.sol";
import { RecoverPayable } from "../commands/Recover.sol";
import { Pipeline } from "../core/Pipeline.sol";
import { PortSettle } from "../ports/Settle.sol";
import { AllowAssets } from "../commands/admin/AllowAssets.sol";
import { DenyAssets } from "../commands/admin/DenyAssets.sol";
import { Allowance } from "../commands/admin/Allowance.sol";
import { PublishSchema } from "../commands/admin/Schemas.sol";
import { HostAmount } from "../core/Types.sol";
import { Budget, Values } from "../utils/Value.sol";
import { Reader, Readers } from "../Cursors.sol";

using Readers for Reader;

contract TestHost is
    Host,
    Allocate,
    Deposit,
    DepositPayable,
    Withdraw,
    CreditAccount,
    DebitAccount,
    Payout,
    Provision,
    ProvisionPayable,
    RelayPayable,
    RecoverPayable,
    Pipeline,
    PortSettle,
    AllowAssets,
    DenyAssets,
    Allowance,
    PublishSchema
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
    event RelayCalled(uint portal, uint resources, bytes context);
    event RecoverCalled(uint handler, bytes32 key, bytes witness, uint128 value);
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
        Budget memory budget
    ) internal override {
        emit DepositPayableCalled(account, asset, Values.use(budget, amount), budget.remaining);
    }

    function withdraw(bytes32 account, bytes32 asset, uint amount) internal override {
        emit WithdrawCalled(account, asset, amount);
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
        Budget memory budget
    ) internal override {
        emit ProvisionPayableCalled(
            custody.host, account, custody.asset, Values.use(budget, custody.amount), budget.remaining
        );
    }

    function route(uint portal, uint resources, bytes memory context, Budget memory budget) internal override {
        budget;
        emit RelayCalled(portal, resources, context);
    }

    function recover(
        uint handler,
        bytes32 key,
        bytes calldata witness,
        uint128 value
    ) internal override {
        emit RecoverCalled(handler, key, witness, value);
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
        bytes32,
        bytes memory state,
        bytes calldata request,
        uint128 value
    ) internal override returns (bytes memory nextState, bytes memory transactions) {
        emit StepDispatched(cid, stepCount++, value);
        if (cid == type(uint).max) return (state, request);
        return (state, "");
    }

    function testPipe(bytes32 account, bytes memory state, bytes calldata steps) external payable {
        Budget memory budget = openValue();
        pipe(account, state, steps, budget);
        Reader memory txs;
        txs.source = closeValue(budget, account);
        while (txs.more()) {
            (bytes32 from, bytes32 to, bytes32 asset, uint amount) = txs.unpackTransaction();
            settle(from, to, asset, amount);
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
        return authorizeId;
    }

    function testUnauthorizeId() external view returns (uint) {
        return unauthorizeId;
    }

    function setGuardianAccount(bytes32 account, bool active) external {
        setGuardian(account, active);
    }

    function isGuardianAddress(address addr) external view returns (bool) {
        return isGuardian(addr);
    }

}




