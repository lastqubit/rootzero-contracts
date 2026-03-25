// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "./Access.sol";
import {Authorize} from "../commands/admin/Authorize.sol";
import {Unauthorize} from "../commands/admin/Unauthorize.sol";
import {Relocate} from "../commands/admin/Relocate.sol";
import {HostAnnouncedEvent} from "../events/HostAnnounced.sol";
import {IHostDiscovery} from "../interfaces/IHostDiscovery.sol";
import {ensureHost} from "../utils/Ids.sol";

abstract contract HostDiscovery is HostAnnouncedEvent, IHostDiscovery {
    function announceHost(uint id, uint blocknum, uint16 version, string calldata namespace) external {
        emit HostAnnounced(ensureHost(id, msg.sender), blocknum, version, namespace);
    }
}

abstract contract Host is Authorize, Unauthorize, Relocate {
    constructor(address fastish, uint8 version, string memory namespace) AccessControl(fastish) {
        if (fastish == address(0) || fastish == address(this) || fastish.code.length == 0) return;
        IHostDiscovery(fastish).announceHost(host, block.number, version, namespace);
    }

    receive() external payable {}
}
