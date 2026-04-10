// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {OperationBase} from "../core/Operation.sol";
import {Cur} from "../Cursors.sol";
import {CommandEvent} from "../events/Command.sol";
import {Channels} from "../utils/Channels.sol";
import {Ids, Selectors} from "../utils/Ids.sol";

struct CommandContext {
    uint target;
    bytes32 account;
    bytes state;
    bytes request;
}

abstract contract CommandBase is OperationBase, CommandEvent {
    error Expired();
    error NotAdmin();
    error UnexpectedEndpoint();

    modifier onlyAdmin(bytes32 account) {
        if (account != adminAccount) revert NotAdmin();
        _;
    }

    modifier onlyCommand(uint cid, uint target) {
        if (target != 0 && target != cid) revert UnexpectedEndpoint();
        enforceCaller(msg.sender);
        _;
    }

    modifier onlyActive(uint deadline) {
        if (deadline < block.timestamp) revert Expired();
        _;
    }

    function commandId(string memory name) internal view returns (uint) {
        return Ids.toCommand(Selectors.command(name), address(this));
    }
}
