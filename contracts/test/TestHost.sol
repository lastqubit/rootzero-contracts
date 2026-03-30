// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Deposit } from "../commands/Deposit.sol";
import { Withdraw } from "../commands/Withdraw.sol";
import { Transfer } from "../commands/Transfer.sol";
import { CreditAccount } from "../commands/Credit.sol";
import { DebitAccount } from "../commands/Debit.sol";
import { Settle } from "../commands/Settle.sol";
import { Provision, ProvisionFromBalance } from "../commands/Provision.sol";
import { Pipe } from "../commands/Pipe.sol";
import { AllowAssets } from "../commands/admin/AllowAssets.sol";
import { DenyAssets } from "../commands/admin/DenyAssets.sol";
import { Destroy } from "../commands/admin/Destroy.sol";
import { Init } from "../commands/admin/Init.sol";
import { Allocate } from "../commands/admin/Allocate.sol";
import { Tx } from "../blocks/Schema.sol";
import { Block } from "../Blocks.sol";

contract TestHost is
    Host,
    Deposit,
    Withdraw,
    Transfer,
    CreditAccount,
    DebitAccount,
    Settle,
    Provision,
    ProvisionFromBalance,
    Pipe,
    Init,
    Destroy,
    AllowAssets,
    DenyAssets,
    Allocate
{
    event DepositCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event WithdrawCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event TransferCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);
    event CreditToCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint returned);
    event DebitFromCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint returned);
    event SettleCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);
    event ProvisionCalled(uint host_, bytes32 account, bytes32 asset, bytes32 meta, uint amount);
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

    function withdraw(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit WithdrawCalled(account, asset, meta, amount);
    }

    function transfer(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit TransferCalled(from_, to_, asset, meta, amount);
    }

    function creditAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit CreditToCalled(account, asset, meta, amount, amount);
    }

    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit DebitFromCalled(account, asset, meta, amount, amount);
    }

    function settle(Tx memory value) internal override {
        emit SettleCalled(value.from, value.to, value.asset, value.meta, value.amount);
    }

    function provision(bytes32 account, uint host_, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit ProvisionCalled(host_, account, asset, meta, amount);
    }

    function init(Block memory rawInput) internal override {
        bytes calldata inputData = msg.data[rawInput.i:rawInput.bound];
        emit InitCalled(inputData);
    }

    function destroy(Block memory rawInput) internal override {
        bytes calldata inputData = msg.data[rawInput.i:rawInput.bound];
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

    function getPipeId() external view returns (uint) {
        return pipeId;
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

    function getRelocateId() external view returns (uint) {
        return relocateId;
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
        return authorized[node];
    }
}
