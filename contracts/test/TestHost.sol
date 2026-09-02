// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Allocate } from "../commands/Allocate.sol";
import { Bootstrap } from "../commands/Bootstrap.sol";
import { ExecuteCashout } from "../commands/Cashout.sol";
import { Deposit, DepositPayable } from "../commands/Deposit.sol";
import { Withdraw } from "../commands/Withdraw.sol";
import { ExecuteCreditAccount } from "../commands/Credit.sol";
import { ExecuteDebitAccount } from "../commands/Debit.sol";
import { Payout } from "../commands/Payout.sol";
import { Provision, ProvisionPayable } from "../commands/Provision.sol";
import { RelayPayable, RelayBalancePayable } from "../commands/Relay.sol";
import { RecoverPayable } from "../commands/Recover.sol";
import { ExecuteRepay, RepayPayable, RepayPosition, RepayPositionPayable } from "../commands/Repay.sol";
import { ExecuteSettle, SettlePayable } from "../commands/Settle.sol";
import { Pipeline } from "../core/Pipeline.sol";
import { Settlement, SettleHook } from "../core/Settlement.sol";
import { PostPort } from "../ports/Post.sol";
import { AllowAssets } from "../commands/admin/AllowAssets.sol";
import { DenyAssets } from "../commands/admin/DenyAssets.sol";
import { Allowance } from "../commands/admin/Allowance.sol";
import { RevokeAllowance, RevokeAsset } from "../guards/Revoke.sol";
import { HostAmount } from "../core/Types.sol";
import { Execution, Executions } from "../execution/Execution.sol";
import { Blocks } from "../codec/Blocks.sol";
import { Specs } from "../codec/Specs.sol";

using Executions for Execution;

contract TestHost is
    Host,
    Allocate,
    Bootstrap,
    ExecuteCashout,
    Deposit,
    DepositPayable,
    Withdraw,
    ExecuteCreditAccount,
    ExecuteDebitAccount,
    Payout,
    Provision,
    ProvisionPayable,
    RelayPayable,
    RelayBalancePayable,
    RecoverPayable,
    ExecuteRepay,
    RepayPayable,
    RepayPosition,
    RepayPositionPayable,
    ExecuteSettle,
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
    event CashoutCalled(bytes32 account, uint amount);
    event DepositCalled(bytes32 account, bytes32 asset, uint amount);
    event DepositPayableCalled(bytes32 account, bytes32 asset, uint amount, uint remaining);
    event WithdrawCalled(bytes32 account, bytes32 asset, uint amount);
    event CreditToCalled(bytes32 account, bytes32 asset, uint amount, uint returned);
    event DebitFromCalled(bytes32 account, bytes32 asset, uint amount, uint returned);
    event PayoutCalled(bytes32 account, bytes32 to, bytes32 asset, uint amount);
    event ProvisionCalled(uint host_, bytes32 account, bytes32 asset, uint amount);
    event ProvisionPayableCalled(uint host_, bytes32 account, bytes32 asset, uint amount, uint remaining);
    event RelayCalled(uint portal, uint resources, bytes32 account, bytes context);
    event RecoverCalled(uint handler, uint resources, bytes32 key, bytes witness, uint value);
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
    constructor(uint rootzero) Host(rootzero) Allocate() Deposit() Provision() {
        schema(3, 64, "uint portal, uint resources", bytes32("relay.input"));
    }

    function allocate(bytes32 account, HostAmount memory custody) internal override {
        emit AllocateCalled(custody.host, account, custody.asset, custody.amount);
    }

    function cashout(bytes32 account, uint amount) internal override {
        emit CashoutCalled(account, amount);
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
        bytes32 account,
        bytes calldata input,
        bytes memory context,
        Execution memory
    ) internal override {
        uint abs = Blocks.exact(input, Specs.create(3, 64));
        uint portal = uint(Blocks.read32(abs));
        uint resources = uint(Blocks.read32(abs + 32));
        emit RelayCalled(portal, resources, account, context);
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

    function execute(
        uint cid,
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint value
    ) internal override returns (bool handled, bytes memory nextState, uint credit) {
        if (cid == bootstrapId()) {
            enforceCommand(cid);
            return executeBootstrap(account, state, input, value);
        }
        if (cid == cashoutId()) {
            enforceCommand(cid);
            return executeCashout(account, state, input, value);
        }
        if (cid == debitAccountId()) {
            enforceCommand(cid);
            return executeDebitAccount(account, state, input, value);
        }
        if (cid == creditAccountId()) {
            enforceCommand(cid);
            return executeCreditAccount(account, state, input, value);
        }
        if (cid == settleId()) {
            enforceCommand(cid);
            return executeSettle(account, state, input, value);
        }
        if (cid == repayId()) {
            enforceCommand(cid);
            return executeRepay(account, state, input, value);
        }
        return (false, state, 0);
    }

    function testPipe(bytes32 account, bytes memory state, bytes calldata steps) external payable {
        Execution memory exec = Executions.open();
        exec.account = account;
        uint budget = exec.drainBudget();
        exec.budget = pipe(account, state, steps, budget);
        uint credit;
        (, credit) = exec.close();
        post(bytes32(0), account, nativeAsset, credit);
    }

    function getAdminAccount() external view returns (bytes32) {
        return admin;
    }

    function getCommander() external view returns (uint) {
        return commander;
    }

    function getCommanderAddr() external view returns (address) {
        return commanderAddr;
    }

    function isAuthorized(uint node) external view returns (bool) {
        return nodes[node];
    }

    function testEnforceNode(uint node) external view returns (bytes4, address) {
        return enforceNode(node);
    }

    function testEnforceCommand(uint cmd) external view returns (bytes4, address) {
        return enforceCommand(cmd);
    }

    function testEnforcePort(uint port) external view returns (bytes4, address) {
        return enforcePort(port);
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




