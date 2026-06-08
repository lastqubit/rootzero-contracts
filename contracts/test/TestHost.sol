// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Deposit, DepositPayable } from "../commands/Deposit.sol";
import { Withdraw } from "../commands/Withdraw.sol";
import { CreditAccount } from "../commands/Credit.sol";
import { DebitAccount } from "../commands/Debit.sol";
import { Payout } from "../commands/Payout.sol";
import { Provision, ProvisionPayable } from "../commands/Provision.sol";
import { RelayPayable } from "../commands/Relay.sol";
import { Pipeline } from "../core/Pipeline.sol";
import { PeerSettle } from "../peer/Settle.sol";
import { AllowAssets } from "../commands/admin/AllowAssets.sol";
import { DenyAssets } from "../commands/admin/DenyAssets.sol";
import { Destroy } from "../commands/admin/Destroy.sol";
import { Init } from "../commands/admin/Init.sol";
import { Allowance } from "../commands/admin/Allowance.sol";
import { HostAmount } from "../core/Types.sol";
import { Cursors, Cur, Keys } from "../Cursors.sol";
import { Budget, Values } from "../utils/Value.sol";

using Cursors for Cur;

contract TestHost is
    Host,
    Deposit,
    DepositPayable,
    Withdraw,
    CreditAccount,
    DebitAccount,
    Payout,
    Provision,
    ProvisionPayable,
    RelayPayable,
    Pipeline,
    PeerSettle,
    Init,
    Destroy,
    AllowAssets,
    DenyAssets,
    Allowance
{
    event DepositCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event DepositPayableCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint remaining);
    event WithdrawCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event CreditToCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint returned);
    event DebitFromCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint returned);
    event PayoutCalled(bytes32 account, bytes32 to, bytes32 asset, bytes32 meta, uint amount);
    event ProvisionCalled(uint host_, bytes32 account, bytes32 asset, bytes32 meta, uint amount);
    event ProvisionPayableCalled(uint host_, bytes32 account, bytes32 asset, bytes32 meta, uint amount, uint remaining);
    event RelayCalled(uint chain, uint resources, bytes pipe);
    event InitCalled(bytes inputData);
    event DestroyCalled(bytes inputData);
    event AllowAssetCalled(bytes32 asset, bytes32 meta);
    event DenyAssetCalled(bytes32 asset, bytes32 meta);
    event AllowanceCalled(uint host_, bytes32 asset, bytes32 meta, uint amount);
    event StepDispatched(uint cid, uint stepIndex, uint128 value);

    uint public stepCount;

    constructor(address rootzero) Host(rootzero) Deposit() Provision() Init("") Destroy("") {}

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
        emit DepositPayableCalled(account, asset, meta, Values.use(budget, uint128(amount)), budget.remaining);
    }

    function withdraw(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit WithdrawCalled(account, asset, meta, amount);
    }

    function creditAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit CreditToCalled(account, asset, meta, amount, amount);
    }

    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit DebitFromCalled(account, asset, meta, amount, amount);
    }

    function payout(bytes32 account, bytes32 to, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit PayoutCalled(account, to, asset, meta, amount);
    }

    function provision(bytes32 account, HostAmount memory custody) internal override {
        emit ProvisionCalled(custody.host, account, custody.asset, custody.meta, custody.amount);
    }

    function provision(
        bytes32 account,
        HostAmount memory custody,
        Budget memory budget
    ) internal override {
        emit ProvisionPayableCalled(
            custody.host, account, custody.asset, custody.meta, Values.use(budget, uint128(custody.amount)), budget.remaining
        );
    }

    function dispatch(uint chain, uint resources, bytes memory pipe, Budget memory budget) internal override {
        budget;
        emit RelayCalled(chain, resources, pipe);
    }

    function init(Cur memory input) internal override {
        (bytes4 key, uint len) = input.peek(input.i);
        bytes calldata inputData;
        if (key == Keys.Data) {
            inputData = input.unpackRaw(Keys.Data);
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
        if (key == Keys.Data) {
            inputData = input.unpackRaw(Keys.Data);
        } else {
            uint next = input.i + 8 + len;
            inputData = msg.data[input.offset + input.i:input.offset + next];
            input.i = next;
        }
        emit DestroyCalled(inputData);
    }

    function allowAsset(bytes32 asset, bytes32 meta) internal override {
        emit AllowAssetCalled(asset, meta);
    }

    function denyAsset(bytes32 asset, bytes32 meta) internal override {
        emit DenyAssetCalled(asset, meta);
    }

    function allowance(uint peer, bytes32 asset, bytes32 meta, uint amount) internal override {
        emit AllowanceCalled(peer, asset, meta, amount);
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

    function testPipe(bytes32 account, bytes memory state, bytes calldata steps) external payable {
        pipe(account, state, steps, valueBudget());
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

    function getCreditAccountId() external view returns (uint) {
        return creditAccountId;
    }

    function getDebitAccountId() external view returns (uint) {
        return debitAccountId;
    }

    function getPayoutId() external view returns (uint) {
        return payoutId;
    }

    function getPeerSettleId() external view returns (uint) {
        return peerSettleId;
    }

    function getProvisionId() external view returns (uint) {
        return provisionId;
    }

    function getProvisionPayableId() external view returns (uint) {
        return provisionPayableId;
    }

    function getRelayPayableId() external view returns (uint) {
        return relayPayableId;
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

    function getAppointId() external view returns (uint) {
        return appointId;
    }

    function getDismissId() external view returns (uint) {
        return dismissId;
    }

    function getExecutePayableId() external view returns (uint) {
        return executePayableId;
    }

    function getLabelId() external view returns (uint) {
        return labelId;
    }

    function getAllowAssetsId() external view returns (uint) {
        return allowAssetsId;
    }

    function getDenyAssetsId() external view returns (uint) {
        return denyAssetsId;
    }

    function getAllowanceId() external view returns (uint) {
        return allowanceId;
    }

    function getRevokeId() external view returns (uint) {
        return revokeId;
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

    function setGuardianAccount(bytes32 account, bool active) external {
        setGuardian(account, active);
    }

    function isGuardianAddress(address addr) external view returns (bool) {
        return isGuardian(addr);
    }

}




