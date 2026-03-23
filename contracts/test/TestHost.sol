// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {Deposit} from "../commands/Deposit.sol";
import {Withdraw} from "../commands/Withdraw.sol";
import {Transfer} from "../commands/Transfer.sol";
import {CreditBalanceToAccount} from "../commands/CreditTo.sol";
import {DebitAccountToBalance} from "../commands/DebitFrom.sol";
import {Settle} from "../commands/Settle.sol";
import {Fund} from "../commands/Fund.sol";
import {Provision} from "../commands/Provision.sol";
import {Pipe} from "../commands/Pipe.sol";
import {AllowAssets} from "../commands/admin/AllowAssets.sol";
import {DenyAssets} from "../commands/admin/DenyAssets.sol";
import {SetAllocations} from "../commands/admin/SetAllocations.sol";
import {Tx, Writer} from "../blocks/Schema.sol";
import {Writers} from "../blocks/Writers.sol";

using Writers for Writer;

contract TestHost is
    Host,
    Deposit,
    Withdraw,
    Transfer,
    CreditBalanceToAccount,
    DebitAccountToBalance,
    Settle,
    Fund,
    Provision,
    Pipe,
    AllowAssets,
    DenyAssets,
    SetAllocations
{
    event DepositCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event WithdrawCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event TransferCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);
    event CreditToCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint returned);
    event DebitFromCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint returned);
    event SettleCalled(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount);
    event FundCalled(uint host_, bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event ProvisionCalled(uint host_, bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event AllowAssetCalled(bytes32 asset, bytes32 meta);
    event DenyAssetCalled(bytes32 asset, bytes32 meta);
    event SetAllocationCalled(uint host_, bytes32 asset, bytes32 meta, uint amount);
    event StepDispatched(uint target, uint stepIndex, uint value);

    uint public stepCount;

    constructor(address rush) Host(rush, 1, "test") Deposit() Provision(10_000) {}

    function deposit(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit DepositCalled(account, asset, meta, amount);
    }

    function withdraw(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit WithdrawCalled(account, asset, meta, amount);
    }

    function transfer(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit TransferCalled(from_, to_, asset, meta, amount);
    }

    function creditBalanceToAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit CreditToCalled(account, asset, meta, amount, amount);
    }

    function debitAccountToBalance(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit DebitFromCalled(account, asset, meta, amount, amount);
    }

    function settle(Tx memory value) internal override {
        emit SettleCalled(value.from, value.to, value.asset, value.meta, value.amount);
    }

    function fund(uint host_, bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit FundCalled(host_, account, asset, meta, amount);
    }

    function provision(
        bytes32 account,
        uint host_,
        bytes32 asset,
        bytes32 meta,
        uint amount,
        Writer memory out
    ) internal override {
        emit ProvisionCalled(host_, account, asset, meta, amount);
        out.appendCustody(host_, asset, meta, amount);
    }

    function allowAsset(bytes32 asset, bytes32 meta) internal override returns (bool) {
        emit AllowAssetCalled(asset, meta);
        return true;
    }

    function denyAsset(bytes32 asset, bytes32 meta) internal override returns (bool) {
        emit DenyAssetCalled(asset, meta);
        return true;
    }

    function setAllocation(uint host_, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit SetAllocationCalled(host_, asset, meta, amount);
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

    function getCreditBalanceToAccountId() external view returns (uint) {
        return creditBalanceToAccountId;
    }

    function getDebitAccountToBalanceId() external view returns (uint) {
        return debitAccountToBalanceId;
    }

    function getSettleId() external view returns (uint) {
        return settleId;
    }

    function getFundId() external view returns (uint) {
        return fundId;
    }

    function getProvisionId() external view returns (uint) {
        return provisionId;
    }

    function getPipeId() external view returns (uint) {
        return pipeId;
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

    function getSetAllocationsId() external view returns (uint) {
        return setAllocationsId;
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
