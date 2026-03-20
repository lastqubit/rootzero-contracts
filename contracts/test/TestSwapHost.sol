// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {SwapExactBalanceToBalance} from "../commands/Swap.sol";
import {AssetAmount, DataRef} from "../Schema.sol";
import {Data} from "../blocks/Data.sol";

using Data for DataRef;

contract TestSwapHost is Host, SwapExactBalanceToBalance {
    event SwapMapped(bytes32 account, bytes32 asset, bytes32 meta, uint amount, bytes routeData);
    event SwapMinimum(bytes32 asset, bytes32 meta, uint amount);

    constructor(address rush)
        Host(rush, 1, "test")
        SwapExactBalanceToBalance("route(bytes data)")
    {}

    function swapExactBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute
    ) internal override returns (AssetAmount memory out) {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit SwapMapped(account, balance.asset, balance.meta, balance.amount, routeData);
        if (rawRoute.bound < rawRoute.end) {
            (bytes32 minAsset, bytes32 minMeta, uint minAmount) = rawRoute.innerMinimum();
            emit SwapMinimum(minAsset, minMeta, minAmount);
        }
        return AssetAmount({
            asset: balance.asset,
            meta: bytes32(rawRoute.bound - rawRoute.i),
            amount: balance.amount + (rawRoute.bound - rawRoute.i)
        });
    }

    function getSwapExactInAsset32Id() external view returns (uint) {
        return swapExactBalanceToBalanceId;
    }

    function getAdminAccount() external view returns (bytes32) {
        return adminAccount;
    }
}
