// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host, AccessControl} from "./Host.sol"; ////
import {Authorize} from "./Commands/Core/Authorize.sol";
import {Unauthorize} from "./Commands/Core/Unauthorize.sol";
import {Relocate} from "./Commands/Core/Relocate.sol";
import {IsTrusted} from "./Queries/IsTrusted.sol";

interface INodeDiscovery {
    function announceNode(uint block0, string calldata name) external;
}

abstract contract Node is Host, Authorize, Unauthorize, Relocate, IsTrusted {
    constructor(address cmdr, address discovery, string memory name) AccessControl(cmdr) {
        if (discovery == address(0)) return;
        INodeDiscovery(discovery).announceNode(block.number, name);
    }

    receive() external payable {}
}
