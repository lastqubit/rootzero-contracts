// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Deposit, DepositPayable } from "../commands/Deposit.sol";
import { Withdraw } from "../commands/Withdraw.sol";
import { Transfer } from "../commands/Transfer.sol";
import { CreditAccount } from "../commands/Credit.sol";
import { DebitAccount } from "../commands/Debit.sol";
import { Settle } from "../commands/Settle.sol";
import { Provision, ProvisionPayable, ProvisionFromBalance } from "../commands/Provision.sol";
import { PipePayable } from "../commands/Pipe.sol";
import { AllowAssets } from "../commands/admin/AllowAssets.sol";
import { DenyAssets } from "../commands/admin/DenyAssets.sol";
import { Destroy } from "../commands/admin/Destroy.sol";
import { Init } from "../commands/admin/Init.sol";
import { Allocate } from "../commands/admin/Allocate.sol";
import { AssetAmount, Tx } from "../core/Types.sol";
import { Cursors, Cursors, Cur, Keys } from "../Cursors.sol";
import { Budget, Values } from "../utils/Value.sol";

using Cursors for Cur;

contract TestHost is
    Host,
    Deposit,
    DepositPayable,
    Withdraw,
    Transfer,
    CreditAccount,
    DebitAccount,
    Settle,
    Provision,
    ProvisionPayable,
    ProvisionFromBalance,
    PipePayable,
    Init,
    Destroy,
    AllowAssets,
    DenyAssets,
    Allocate
{
    event DepositCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event DepositPayableCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint remaining);
    event WithdrawCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event TransferCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);
    event CreditToCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint returned);
    event DebitFromCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint returned);
    event SettleCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);
    event ProvisionCalled(uint host_, bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event ProvisionPayableCalled(uint host_, bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint remaining);
    event InitCalled(bytes inputData);
    event DestroyCalled(bytes inputData);
    event AllowAssetCalled(bytes32 asset, bytes32 meta);
    event DenyAssetCalled(bytes32 asset, bytes32 meta);
    event AllocateCalled(uint host_, bytes32 asset, bytes32 meta, uint amount);
    event StepDispatched(uint target, uint stepIndex, uint value);

    uint public stepCount;

    constructor(address rootzero) Host(rootzero, 1, "test") Deposit() Provision() Init("") Destroy("") {}

    function deposit(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit DepositCalled(account, asset, meta, amount);
    }

    function deposit(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount,
        Budget memory budget
    ) internal override {
        emit DepositPayableCalled(account, asset, meta, Values.use(budget, amount), budget.remaining);
    }

    function withdraw(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit WithdrawCalled(account, asset, meta, amount);
    }

    function transfer(Tx memory value) internal override {
        emit TransferCalled(value.from, value.to, value.asset, value.meta, value.amount);
        emit SettleCalled(value.from, value.to, value.asset, value.meta, value.amount);
    }

    function creditAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit CreditToCalled(account, asset, meta, amount, amount);
    }

    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit DebitFromCalled(account, asset, meta, amount, amount);
    }

    function provision(uint host_, bytes32 account, AssetAmount memory custody) internal override {
        emit ProvisionCalled(host_, account, custody.asset, custody.meta, custody.amount);
    }

    function provision(
        uint host_,
        bytes32 account,
        AssetAmount memory custody,
        Budget memory budget
    ) internal override {
        emit ProvisionPayableCalled(
            host_, account, custody.asset, custody.meta, Values.use(budget, custody.amount), budget.remaining
        );
    }

    function init(Cur memory input) internal override {
        (bytes4 key, uint len) = input.peek(input.i);
        bytes calldata inputData;
        if (key == Keys.Route) {
            inputData = input.unpackRaw(Keys.Route);
        } else {
            uint next = input.i + 8 + len;
            inputData = msg.data[input.offset + input.i:input.offset + next];
            input.i = next;
        }
        emit InitCalled(inputData);
    }

    function destroy(Cur memory input) internal override {
        (bytes4 key, uint len) = input.peek(input.i);
        bytes calldata inputData;
        if (key == Keys.Route) {
            inputData = input.unpackRaw(Keys.Route);
        } else {
            uint next = input.i + 8 + len;
            inputData = msg.data[input.offset + input.i:input.offset + next];
            input.i = next;
        }
        emit DestroyCalled(inputData);
    }

    function allowAsset(bytes32 asset, bytes32 meta) internal override returns (bool) {
        emit AllowAssetCalled(asset, meta);
        return true;
    }

    function denyAsset(bytes32 asset, bytes32 meta) internal override returns (bool) {
        emit DenyAssetCalled(asset, meta);
        return true;
    }

    function allocate(uint host_, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit AllocateCalled(host_, asset, meta, amount);
    }

    function dispatchStep(
        uint target,
        bytes32,
        bytes memory state,
        bytes calldata,
        uint value
    ) internal override returns (bytes memory) {
        emit StepDispatched(target, stepCount++, value);
        return state;
    }

    // Expose internal host/admin IDs for tests
    function getDepositId() external view returns (uint) {
        return depositId;
    }

    function getDepositPayableId() external view returns (uint) {
        return depositPayableId;
    }

    function getWithdrawId() external view returns (uint) {
        return withdrawId;
    }

    function getTransferId() external view returns (uint) {
        return transferId;
    }

    function getCreditAccountId() external view returns (uint) {
        return creditAccountId;
    }

    function getDebitAccountId() external view returns (uint) {
        return debitAccountId;
    }

    function getSettleId() external view returns (uint) {
        return settleId;
    }

    function getProvisionFromBalanceId() external view returns (uint) {
        return provisionFromBalanceId;
    }

    function getProvisionId() external view returns (uint) {
        return provisionId;
    }

    function getProvisionPayableId() external view returns (uint) {
        return provisionPayableId;
    }

    function getPipePayableId() external view returns (uint) {
        return pipePayableId;
    }

    function getInitId() external view returns (uint) {
        return initId;
    }

    function getDestroyId() external view returns (uint) {
        return destroyId;
    }

    function getAuthorizeId() external view returns (uint) {
        return authorizeId;
    }

    function getUnauthorizeId() external view returns (uint) {
        return unauthorizeId;
    }

    function getRelocatePayableId() external view returns (uint) {
        return relocatePayableId;
    }

    function getExecutePayableId() external view returns (uint) {
        return executePayableId;
    }

    function getAllowAssetsId() external view returns (uint) {
        return allowAssetsId;
    }

    function getDenyAssetsId() external view returns (uint) {
        return denyAssetsId;
    }

    function getAllocateId() external view returns (uint) {
        return allocateId;
    }

    function getAdminAccount() external view returns (bytes32) {
        return adminAccount;
    }

    function getCommander() external view returns (address) {
        return commander;
    }

    function isAuthorized(uint node) external view returns (bool) {
        return trusted[node];
    }
}




