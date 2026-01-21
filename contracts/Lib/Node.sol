// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Id, Host} from "./Host.sol"; ////
import {Authorize} from "./Commands/Core/Authorize.sol";
import {Unauthorize} from "./Commands/Core/Unauthorize.sol";
import {Relocate} from "./Commands/Core/Relocate.sol";
import {GetTrusted} from "./Queries/GetTrusted.sol";
import {IDiscovery} from "./Discovery.sol";

abstract contract Node is Host, Authorize, Unauthorize, Relocate, GetTrusted {
    uint public immutable valueId = Id.ensure(Id.value());
    uint internal immutable nodeId = hostId; //////

    constructor(address rush, address discovery, string memory name) {
        admin = rush == address(0) ? address(this) : rush;
        IDiscovery(discovery).announce(name);
    }

    function getTrusted(address addr) external view override returns (bool) {
        return isTrusted(addr);
    }

    receive() external payable {}
}
