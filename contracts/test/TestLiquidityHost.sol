// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { AddLiquidityFromCustodiesToBalances, RemoveLiquidityFromCustodyToBalances, AddLiquidityFromBalancesToBalances, RemoveLiquidityFromBalanceToBalances } from "../commands/Liquidity.sol";
import { AssetAmount, HostAmount } from "../blocks/Schema.sol";
import { Cur, Cursors, Writer, Keys } from "../Cursors.sol";
import { Writers } from "../blocks/Writers.sol";
import { Ids } from "../utils/Ids.sol";

using Cursors for Cur;
using Writers for Writer;

contract TestLiquidityHost is
    Host,
    AddLiquidityFromCustodiesToBalances,
    RemoveLiquidityFromCustodyToBalances,
    AddLiquidityFromBalancesToBalances,
    RemoveLiquidityFromBalanceToBalances
{
    bytes32 internal constant LP_FROM_CUSTODIES_ASSET = bytes32(uint(0xaaa1));
    bytes32 internal constant LP_FROM_BALANCES_ASSET = bytes32(uint(0xaaa2));
    bytes32 internal constant REDEEM_FROM_CUSTODY_ASSET = bytes32(uint(0xbbb1));
    bytes32 internal constant REDEEM_FROM_BALANCE_ASSET = bytes32(uint(0xbbb2));

    event AddCustodiesMapped(
        bytes32 account,
        bytes32 assetA,
        uint amountA,
        bytes32 assetB,
        uint amountB,
        bytes bundleData
    );
    event RemoveCustodyMapped(bytes32 account, bytes32 asset, uint amount, bytes bundleData);
    event AddBalancesMapped(
        bytes32 account,
        bytes32 assetA,
        uint amountA,
        bytes32 assetB,
        uint amountB,
        bytes bundleData
    );
    event RemoveBalanceMapped(bytes32 account, bytes32 asset, uint amount, bytes bundleData);
    event MinimumObserved(bytes32 asset, bytes32 meta, uint amount);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        AddLiquidityFromCustodiesToBalances("bundle(bytes data)", 15_000)
        RemoveLiquidityFromCustodyToBalances("bundle(bytes data)", 20_000)
        AddLiquidityFromBalancesToBalances("bundle(bytes data)", 15_000)
        RemoveLiquidityFromBalanceToBalances("bundle(bytes data)", 20_000)
    {
        if (cmdr != address(0)) access(Ids.toHost(cmdr), true);
    }

    function addLiquidityFromCustodiesToBalances(
        bytes32 account,
        Cur memory custodies,
        Cur memory request,
        Writer memory out
    ) internal override {
        HostAmount memory a = custodies.unpackCustodyValue();
        HostAmount memory b = custodies.unpackCustodyValue();
        (bytes calldata bundleData, Cur memory input) = inputData(request);
        uint bundleLen = bundleData.length;
        emit AddCustodiesMapped(account, a.asset, a.amount, b.asset, b.amount, bundleData);
        emitMinimum(input);

        out.appendBalance(a.asset, a.meta, a.amount + bundleLen);
        out.appendBalance(b.asset, b.meta, b.amount + bundleLen + 1);
        out.appendBalance(LP_FROM_CUSTODIES_ASSET, bytes32(bundleLen), a.amount + b.amount);
    }

    function removeLiquidityFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request,
        Writer memory out
    ) internal override {
        (bytes calldata bundleData, Cur memory input) = inputData(request);
        uint bundleLen = bundleData.length;
        emit RemoveCustodyMapped(account, custody.asset, custody.amount, bundleData);
        emitMinimum(input);

        out.appendBalance(custody.asset, custody.meta, custody.amount + bundleLen);
        out.appendBalance(REDEEM_FROM_CUSTODY_ASSET, bytes32(bundleLen), custody.amount + 10);
    }

    function addLiquidityFromBalancesToBalances(
        bytes32 account,
        Cur memory balances,
        Cur memory request,
        Writer memory out
    ) internal override {
        AssetAmount memory a = balances.unpackBalanceValue();
        AssetAmount memory b = balances.unpackBalanceValue();
        (bytes calldata bundleData, Cur memory input) = inputData(request);
        uint bundleLen = bundleData.length;
        emit AddBalancesMapped(account, a.asset, a.amount, b.asset, b.amount, bundleData);
        emitMinimum(input);

        out.appendBalance(a.asset, a.meta, a.amount + bundleLen);
        out.appendBalance(b.asset, b.meta, b.amount + bundleLen + 2);
        out.appendBalance(LP_FROM_BALANCES_ASSET, bytes32(bundleLen), a.amount + b.amount);
    }

    function removeLiquidityFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request,
        Writer memory out
    ) internal override {
        (bytes calldata bundleData, Cur memory input) = inputData(request);
        uint bundleLen = bundleData.length;
        emit RemoveBalanceMapped(account, balance.asset, balance.amount, bundleData);
        emitMinimum(input);

        out.appendBalance(balance.asset, balance.meta, balance.amount + bundleLen);
        out.appendBalance(REDEEM_FROM_BALANCE_ASSET, bytes32(bundleLen), balance.amount + 20);
    }

    function inputData(Cur memory request) internal pure returns (bytes calldata data, Cur memory input) {
        if (request.i == request.len) return (msg.data[0:0], request);
        (bytes4 key, uint len) = request.peek(request.i);
        if (key == Keys.Bundle) {
            input = request.bundle();
            return (msg.data[input.offset:input.offset + input.len], input);
        }

        uint next = request.i + 8 + len;
        data = msg.data[request.offset + request.i:request.offset + next];
        request.i = next;
        return (data, request);
    }

    function emitMinimum(Cur memory input) internal {
        while (input.i < input.len) {
            (bytes4 key, uint len) = input.peek(input.i);
            if (key == Keys.Minimum) {
                (bytes32 asset, bytes32 meta, uint amount) = input.unpackMinimum();
                emit MinimumObserved(asset, meta, amount);
                return;
            }
            input.i += 8 + len;
        }
    }

    function getAddLiquidityFromCustodiesToBalancesId() external view returns (uint) {
        return addLiquidityFromCustodiesToBalancesId;
    }

    function getRemoveLiquidityFromCustodyToBalancesId() external view returns (uint) {
        return removeLiquidityFromCustodyToBalancesId;
    }

    function getAddLiquidityFromBalancesToBalancesId() external view returns (uint) {
        return addLiquidityFromBalancesToBalancesId;
    }

    function getRemoveLiquidityFromBalanceToBalancesId() external view returns (uint) {
        return removeLiquidityFromBalanceToBalancesId;
    }
}




