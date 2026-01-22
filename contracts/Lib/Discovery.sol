// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {DiscoverEvent} from "./Events/Node/Discover.sol";
import {Id} from "./Utils/Id.sol";

interface IDiscovery {
    function broadcast(string calldata name) external;
}

contract Discovery is DiscoverEvent, IDiscovery {
    function broadcast(string calldata name) external {
        emit Discover(Id.host(msg.sender), tx.origin, block.number, name);
    }
}
