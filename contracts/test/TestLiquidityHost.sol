// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { AddLiquidityFromCustodiesToBalances, RemoveLiquidityFromCustodyToBalances, AddLiquidityFromBalancesToBalances, RemoveLiquidityFromBalanceToBalances } from "../commands/Liquidity.sol";
import { Blocks } from "../blocks/Blocks.sol";
import { AssetAmount, HostAmount } from "../blocks/Schema.sol";
import { Block, Writer, Keys } from "../Blocks.sol";
import { Writers } from "../blocks/Writers.sol";
import { Ids } from "../utils/Ids.sol";

using Blocks for Block;
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
        Block memory custodiesView,
        Block memory rawBundle,
        Writer memory out
    ) internal override {
        HostAmount memory a = custodiesView.member(0).toCustodyValue();
        HostAmount memory b = custodiesView.member(1).toCustodyValue();
        bytes calldata bundleData = msg.data[rawBundle.i:rawBundle.bound];
        uint bundleLen = rawBundle.bound - rawBundle.i;
        emit AddCustodiesMapped(account, a.asset, a.amount, b.asset, b.amount, bundleData);
        emitMinimum(rawBundle);

        out.appendBalance(a.asset, a.meta, a.amount + bundleLen);
        out.appendBalance(b.asset, b.meta, b.amount + bundleLen + 1);
        out.appendBalance(LP_FROM_CUSTODIES_ASSET, bytes32(bundleLen), a.amount + b.amount);
    }

    function removeLiquidityFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Block memory rawBundle,
        Writer memory out
    ) internal override {
        bytes calldata bundleData = msg.data[rawBundle.i:rawBundle.bound];
        uint bundleLen = rawBundle.bound - rawBundle.i;
        emit RemoveCustodyMapped(account, custody.asset, custody.amount, bundleData);
        emitMinimum(rawBundle);

        out.appendBalance(custody.asset, custody.meta, custody.amount + bundleLen);
        out.appendBalance(REDEEM_FROM_CUSTODY_ASSET, bytes32(bundleLen), custody.amount + 10);
    }

    function addLiquidityFromBalancesToBalances(
        bytes32 account,
        Block memory balancesView,
        Block memory rawBundle,
        Writer memory out
    ) internal override {
        AssetAmount memory a = balancesView.member(0).toBalanceValue();
        AssetAmount memory b = balancesView.member(1).toBalanceValue();
        bytes calldata bundleData = msg.data[rawBundle.i:rawBundle.bound];
        uint bundleLen = rawBundle.bound - rawBundle.i;
        emit AddBalancesMapped(account, a.asset, a.amount, b.asset, b.amount, bundleData);
        emitMinimum(rawBundle);

        out.appendBalance(a.asset, a.meta, a.amount + bundleLen);
        out.appendBalance(b.asset, b.meta, b.amount + bundleLen + 2);
        out.appendBalance(LP_FROM_BALANCES_ASSET, bytes32(bundleLen), a.amount + b.amount);
    }

    function removeLiquidityFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Block memory rawBundle,
        Writer memory out
    ) internal override {
        bytes calldata bundleData = msg.data[rawBundle.i:rawBundle.bound];
        uint bundleLen = rawBundle.bound - rawBundle.i;
        emit RemoveBalanceMapped(account, balance.asset, balance.amount, bundleData);
        emitMinimum(rawBundle);

        out.appendBalance(balance.asset, balance.meta, balance.amount + bundleLen);
        out.appendBalance(REDEEM_FROM_BALANCE_ASSET, bytes32(bundleLen), balance.amount + 20);
    }

    function emitMinimum(Block memory rawBundle) internal {
        uint i = rawBundle.i;
        while (i < rawBundle.bound) {
            Block memory member = rawBundle.memberAt(i);
            if (member.key == Keys.Minimum) {
                (bytes32 asset, bytes32 meta, uint amount) = member.unpackMinimum();
                emit MinimumObserved(asset, meta, amount);
                return;
            }
            i = member.cursor;
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
