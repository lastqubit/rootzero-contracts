// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AccessControl} from "../core/Access.sol";
import {CommandEvent} from "../events/Command.sol";
import {toValueAsset} from "../utils/Assets.sol";
import {localNodeAddr, toCommandId, toCommandSelector} from "../utils/Ids.sol";

// channels
uint8 constant SETUP = 0x0001;
uint8 constant PIPE = 0x0002;
uint8 constant BALANCES = 0x0003;
uint8 constant TRANSACTIONS = 0x0004;
uint8 constant CUSTODIES = 0x0005;

struct CommandContext {
    uint target;
    bytes32 account;
    bytes state;
    bytes request;
}

error NoOperation();

abstract contract CommandBase is AccessControl, CommandEvent {
    bytes32 public immutable valueAsset = toValueAsset();

    error Expired();
    error NotAdmin(bytes32 value);
    error UnexpectedEndpoint();
    error FailedCall(address addr, uint node, bytes4 selector, bytes err);

    modifier onlyAdmin(bytes32 account) {
        if (account != adminAccount) revert NotAdmin(account);
        _;
    }

    modifier onlyCommand(uint cid, uint target) {
        if (target != 0 && target != cid) revert UnexpectedEndpoint();
        enforceCaller(msg.sender);
        _;
    }

    modifier onlyTrusted() {
        enforceCaller(msg.sender);
        _;
    }

    modifier onlyActive(uint deadline) {
        if (deadline < block.timestamp) revert Expired();
        _;
    }

    function commandId(string memory name) internal view returns (uint) {
        return toCommandId(toCommandSelector(name), address(this));
    }

    function done(uint start, uint end) internal pure returns (bytes memory) {
        if (end <= start) revert NoOperation();
        return "";
    }

    function done(bytes memory state, uint start, uint end) internal pure returns (bytes memory) {
        if (end <= start) revert NoOperation();
        return state;
    }

    function callTo(uint node, uint value, bytes memory data) internal returns (bytes memory out) {
        bool success;
        address addr = localNodeAddr(ensureTrusted(node));
        (success, out) = payable(addr).call{value: value}(data);
        if (!success) {
            revert FailedCall(addr, node, bytes4(data), out);
        }
    }
}
