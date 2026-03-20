// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {ReclaimBalance} from "../commands/Reclaim.sol";
import {AssetAmount, DataRef} from "../blocks/Schema.sol";
import {Data} from "../blocks/Data.sol";
import {toHostId} from "../utils/Ids.sol";

using Data for DataRef;

contract TestReclaimHost is Host, ReclaimBalance {
    event ReclaimCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, bytes routeData);

    bytes32 public returnAsset;
    bytes32 public returnMeta;
    uint    public returnAmount;

    constructor(address cmdr)
        Host(address(0), 1, "test")
        ReclaimBalance("")
    {
        if (cmdr != address(0)) access(toHostId(cmdr), true);
    }

    function setReturn(bytes32 asset, bytes32 meta, uint amount) external {
        returnAsset = asset;
        returnMeta  = meta;
        returnAmount = amount;
    }

    function reclaimBalance(
        bytes32 account,
        AssetAmount memory amount,
        DataRef memory rawRoute
    ) internal override returns (AssetAmount memory) {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit ReclaimCalled(account, amount.asset, amount.meta, amount.amount, routeData);
        return AssetAmount({asset: returnAsset, meta: returnMeta, amount: returnAmount});
    }

    function getReclaimBalanceId() external view returns (uint) { return reclaimBalanceId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}
