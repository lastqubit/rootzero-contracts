// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {AnnouncedEvent} from "../Events/Node/Announced.sol";
import {IHostDiscovery} from "../Host.sol";
import {ensureNode} from "../Utils.sol";

abstract contract Discovery is AnnouncedEvent, IHostDiscovery {
    function announce(uint id, uint block0, string calldata namespace) external {
        emit Announced(ensureNode(id, msg.sender), tx.origin, block0, namespace);
    }
}
