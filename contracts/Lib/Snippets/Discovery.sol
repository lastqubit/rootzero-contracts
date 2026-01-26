// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {AnnouncedEvent} from "../Events/Node/Announced.sol";
import {INodeDiscovery} from "../Node.sol";
import {ensureHost} from "../Utils.sol";

abstract contract Discovery is AnnouncedEvent, INodeDiscovery {
    function announce(uint id, uint block0, string calldata name) external {
        emit Announced(ensureHost(id, msg.sender), tx.origin, block0, name);
    }
}
