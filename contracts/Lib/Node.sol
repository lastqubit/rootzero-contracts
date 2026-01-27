// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host, AccessControl} from "./Host.sol"; ////
import {Authorize} from "./Commands/Core/Admin/Authorize.sol";
import {Unauthorize} from "./Commands/Core/Admin/Unauthorize.sol";
import {Relocate} from "./Commands/Core/Admin/Relocate.sol";
import {IsTrusted} from "./Queries/IsTrusted.sol";

interface INodeDiscovery {
    function announce(uint id, uint block0, string calldata name) external;
}

abstract contract Node is Host, Authorize, Unauthorize, Relocate, IsTrusted {
    constructor(address cmdr, address discovery, string memory name) AccessControl(cmdr) {
        if (discovery == address(0)) return;
        INodeDiscovery(discovery).announce(hostId, block.number, name);
    }

    receive() external payable {}
}
