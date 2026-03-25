// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {Burn} from "../commands/Burn.sol";
import {toHostId} from "../utils/Ids.sol";

contract TestBurnHost is Host, Burn {
    event BurnCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        Burn("")
    {
        if (cmdr != address(0)) access(toHostId(cmdr), true);
    }

    function burn(bytes32 account, bytes32 asset, bytes32 meta, uint amount)
        internal override
        returns (uint)
    {
        emit BurnCalled(account, asset, meta, amount);
        return amount;
    }

    function getBurnId() external view returns (uint) { return burnId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}
