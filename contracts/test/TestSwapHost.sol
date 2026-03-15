// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {SwapExactInAsset32} from "../commands/SwapExactIn.sol";
import {AssetAmount, DataRef} from "../blocks/Schema.sol";

contract TestSwapHost is Host, SwapExactInAsset32 {
    event SwapMapped(bytes32 account, bytes32 asset, bytes32 meta, uint amount, bytes routeData);

    constructor(address cmdr, address discovery)
        Host(cmdr, discovery, 1, "test")
        SwapExactInAsset32("route(bytes data)")
    {}

    function mapBalanceWithRequestRoute(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount,
        DataRef memory rawRoute
    ) internal override returns (bool keep, AssetAmount memory out) {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit SwapMapped(account, asset, meta, amount, routeData);
        return (
            true,
            AssetAmount({
                asset: asset,
                meta: bytes32(rawRoute.bound - rawRoute.i),
                amount: amount + (rawRoute.bound - rawRoute.i)
            })
        );
    }

    function getSwapExactInAsset32Id() external view returns (uint) {
        return swapExactInAsset32Id;
    }

    function getAdminAccount() external view returns (bytes32) {
        return adminAccount;
    }
}
