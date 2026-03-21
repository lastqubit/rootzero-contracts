// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {HostAnnouncedEvent} from "../events/HostAnnounced.sol";
import {ensureHost} from "../utils/Ids.sol";
import {IHostDiscovery} from "../interfaces/IHostDiscovery.sol";

abstract contract HostDiscovery is HostAnnouncedEvent, IHostDiscovery {
    function announceHost(uint id, uint blocknum, uint16 version, string calldata namespace) external {
        emit HostAnnounced(ensureHost(id, msg.sender), blocknum, version, namespace);
    }
}
