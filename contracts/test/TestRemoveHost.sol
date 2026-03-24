// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {Remove} from "../commands/Remove.sol";
import {DataRef} from "../blocks/Schema.sol";
import {toHostId} from "../utils/Ids.sol";

contract TestRemoveHost is Host, Remove {
    event RemoveCalled(bytes32 account, bytes routeData);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        Remove("")
    {
        if (cmdr != address(0)) access(toHostId(cmdr), true);
    }

    function remove(bytes32 account, DataRef memory rawRoute) internal override {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit RemoveCalled(account, routeData);
    }

    function getRemoveId() external view returns (uint) { return removeId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}
