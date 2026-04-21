// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Supply } from "../commands/Supply.sol";
import { AssetAmount } from "../core/Types.sol";
import { Ids } from "../utils/Ids.sol";

contract TestSupplyHost is Host, Supply {
    event SupplyCalled(bytes32 account, uint host, bytes32 asset, bytes32 meta, uint amount);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        Supply()
    {
        if (cmdr != address(0)) authorize(Ids.toHost(cmdr));
    }

    function supply(uint host, bytes32 account, AssetAmount memory value) internal override {
        emit SupplyCalled(account, host, value.asset, value.meta, value.amount);
    }

    function getSupplyId() external view returns (uint) { return supplyId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}
