// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {DiscoverEvent} from "../Events/Node/Discover.sol";
import {INodeDiscovery} from "../Node.sol";
import {toHostId} from "../Utils.sol";

abstract contract Discovery is DiscoverEvent, INodeDiscovery {
    function announceNode(uint block0, string calldata name) external {
        emit Discover(toHostId(msg.sender), tx.origin, block0, name);
    }
}