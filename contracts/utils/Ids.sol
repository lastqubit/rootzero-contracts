// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {COMMAND, EVM32, HOST, NODE} from "./Layout.sol";
import {bytes32ToString} from "./Strings.sol";
import {isLocalFamily, matchesBase, toLocalBase} from "./Utils.sol";

error InvalidId();

uint24 constant NODE_FAMILY = (uint24(EVM32) << 8) | uint24(NODE);
uint32 constant HOST_PREFIX = (uint32(EVM32) << 16) | (uint32(NODE) << 8) | uint32(HOST);
uint32 constant COMMAND_PREFIX = (uint32(EVM32) << 16) | (uint32(NODE) << 8) | uint32(COMMAND);
string constant COMMAND_ARGS = "((uint256,bytes32,bytes,bytes))";

function isHost(uint id) pure returns (bool) {
    return uint32(id >> 224) == HOST_PREFIX;
}

function isCommand(uint id) pure returns (bool) {
    return uint32(id >> 224) == COMMAND_PREFIX;
}

function toHostId(address addr) view returns (uint) {
    return toLocalBase(HOST_PREFIX) | uint(uint160(addr));
}

function toCommandSelector(string memory name) pure returns (bytes4) {
    return bytes4(keccak256(bytes.concat(bytes(name), bytes(COMMAND_ARGS))));
}

function toCommandSelector(bytes32 name) pure returns (bytes4) {
    return toCommandSelector(bytes32ToString(name));
}

function toCommandId(bytes4 selector, address addr) view returns (uint) {
    uint id = toLocalBase(COMMAND_PREFIX) | uint(uint160(addr));
    id |= uint(uint32(selector)) << 160;
    return id;
}

function ensureHost(uint id, address addr) view returns (uint) {
    if (id != toHostId(addr)) revert InvalidId();
    return id;
}

function ensureCommand(uint id) pure returns (uint cid) {
    if (!isCommand(id)) revert InvalidId();
    return id;
}

function localNodeAddr(uint node) view returns (address) {
    if (!isLocalFamily(node, NODE_FAMILY)) revert InvalidId();
    return address(uint160(node));
}

function localHostAddr(uint host) view returns (address) {
    if (!matchesBase(bytes32(host), toLocalBase(HOST_PREFIX))) revert InvalidId();
    return address(uint160(host));
}
