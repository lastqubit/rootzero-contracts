// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {Create} from "../commands/Create.sol";
import {DataRef} from "../blocks/Schema.sol";
import {toHostId} from "../utils/Ids.sol";

contract TestCreateHost is Host, Create {
    event CreateCalled(bytes32 account, bytes routeData);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        Create("")
    {
        if (cmdr != address(0)) access(toHostId(cmdr), true);
    }

    function create(bytes32 account, DataRef memory rawRoute) internal override {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit CreateCalled(account, routeData);
    }

    function getCreateId() external view returns (uint) { return createId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}
