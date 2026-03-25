// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {ReclaimToBalances} from "../commands/Reclaim.sol";
import {AssetAmount, DataRef, Writer} from "../blocks/Schema.sol";
import {Data} from "../blocks/Data.sol";
import {Writers} from "../blocks/Writers.sol";
import {toHostId} from "../utils/Ids.sol";

using Data for DataRef;
using Writers for Writer;

contract TestReclaimHost is Host, ReclaimToBalances {
    event ReclaimCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, bytes routeData);

    bytes32 public returnAsset;
    bytes32 public returnMeta;
    uint    public returnAmount;

    constructor(address cmdr)
        Host(address(0), 1, "test")
        ReclaimToBalances("", 10_000)
    {
        if (cmdr != address(0)) access(toHostId(cmdr), true);
    }

    function setReturn(bytes32 asset, bytes32 meta, uint amount) external {
        returnAsset = asset;
        returnMeta  = meta;
        returnAmount = amount;
    }

    function reclaimToBalances(
        bytes32 account,
        AssetAmount memory amount,
        DataRef memory rawRoute,
        Writer memory out
    ) internal override {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit ReclaimCalled(account, amount.asset, amount.meta, amount.amount, routeData);
        if (returnAmount > 0) out.appendBalance(returnAsset, returnMeta, returnAmount);
    }

    function getReclaimBalanceId() external view returns (uint) { return reclaimToBalancesId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}
