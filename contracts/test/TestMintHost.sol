// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {MintToBalances} from "../commands/Mint.sol";
import {DataRef, Writer} from "../blocks/Schema.sol";
import {Writers} from "../blocks/Writers.sol";
import {toHostId} from "../utils/Ids.sol";

using Writers for Writer;

contract TestMintHost is Host, MintToBalances {
    event MintCalled(bytes32 account, bytes routeData);

    bytes32 public returnAsset;
    bytes32 public returnMeta;
    uint    public returnAmount;

    constructor(address cmdr)
        Host(address(0), 1, "test")
        MintToBalances("", 10_000)
    {
        if (cmdr != address(0)) access(toHostId(cmdr), true);
    }

    function setReturn(bytes32 asset, bytes32 meta, uint amount) external {
        returnAsset = asset;
        returnMeta  = meta;
        returnAmount = amount;
    }

    function mintToBalances(bytes32 account, DataRef memory rawRoute, Writer memory out) internal override {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit MintCalled(account, routeData);
        if (returnAmount > 0) out.appendBalance(returnAsset, returnMeta, returnAmount);
    }

    function getMintId() external view returns (uint) { return mintToBalancesId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}
