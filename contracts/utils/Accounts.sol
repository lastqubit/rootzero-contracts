// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {ACCOUNT, ADMIN, EVM32, USER} from "./Layout.sol";
import {isFamily, toLocalBase, toUnspecifiedBase} from "./Utils.sol";

error InvalidAccount();

uint24 constant ACCOUNT_FAMILY = (uint24(EVM32) << 8) | uint24(ACCOUNT);
uint32 constant ADMIN_PREFIX = (uint32(EVM32) << 16) | (uint32(ACCOUNT) << 8) | uint32(ADMIN);
uint32 constant USER_PREFIX = (uint32(EVM32) << 16) | (uint32(ACCOUNT) << 8) | uint32(USER);

function addrOr(address addr, address or) pure returns (address) {
    return addr == address(0) ? or : addr;
}

function accountPrefix(bytes32 account) pure returns (uint32) {
    return uint32(uint(account) >> 224);
}

function isAdminAccount(bytes32 account) pure returns (bool) {
    return accountPrefix(account) == ADMIN_PREFIX;
}

function toAdminAccount(address addr) view returns (bytes32) {
    return bytes32(toLocalBase(ADMIN_PREFIX) | (uint(uint160(addr)) << 32));
}

function toUserAccount(address addr) pure returns (bytes32) {
    return bytes32(toUnspecifiedBase(USER_PREFIX) | (uint(uint160(addr)) << 32));
}

function ensureEvmAccount(bytes32 account) pure {
    if (!isFamily(uint(account), ACCOUNT_FAMILY)) {
        revert InvalidAccount();
    }
}

function accountEvmAddr(bytes32 account) pure returns (address) {
    ensureEvmAccount(account);
    return address(uint160(uint(account) >> 32));
}
