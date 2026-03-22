// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ROUTE_EMPTY} from "../blocks/Schema.sol";

uint16 constant MAX_BPS = 10_000;

error ValueOverflow();

function max8(uint value) pure returns (uint) {
    if (value > type(uint8).max) {
        revert ValueOverflow();
    }
    return value;
}

function max16(uint value) pure returns (uint) {
    if (value > type(uint16).max) {
        revert ValueOverflow();
    }
    return value;
}

function max24(uint value) pure returns (uint) {
    if (value > type(uint24).max) {
        revert ValueOverflow();
    }
    return value;
}

function max32(uint value) pure returns (uint) {
    if (value > type(uint32).max) {
        revert ValueOverflow();
    }
    return value;
}

function max40(uint value) pure returns (uint) {
    if (value > type(uint40).max) {
        revert ValueOverflow();
    }
    return value;
}

function max64(uint value) pure returns (uint) {
    if (value > type(uint64).max) {
        revert ValueOverflow();
    }
    return value;
}

function max96(uint value) pure returns (uint) {
    if (value > type(uint96).max) {
        revert ValueOverflow();
    }
    return value;
}

function max128(uint value) pure returns (uint) {
    if (value > type(uint128).max) {
        revert ValueOverflow();
    }
    return value;
}

function max160(uint value) pure returns (uint) {
    if (value > type(uint160).max) {
        revert ValueOverflow();
    }
    return value;
}

function toLocalBase(uint32 prefix) view returns (uint) {
    return (uint(prefix) << 224) | (uint(max32(block.chainid)) << 192);
}

function toLocalFamily(uint24 family) view returns (uint) {
    return (uint(family) << 232) | (uint(max32(block.chainid)) << 192);
}

function toUnspecifiedBase(uint32 prefix) pure returns (uint) {
    return uint(prefix) << 224;
}

function isFamily(uint value, uint24 family) pure returns (bool) {
    return uint24(value >> 232) == family;
}

function isLocal(uint value) view returns (bool) {
    return uint32(value >> 192) == block.chainid;
}

function isLocalFamily(uint value, uint24 family) view returns (bool) {
    return isFamily(value, family) && isLocal(value);
}

function matchesBase(bytes32 value, uint base) pure returns (bool) {
    return uint64(uint(value) >> 192) == uint64(base >> 192);
}

function applyBps(uint amount, uint16 bps) pure returns (uint) {
    if (amount == 0 || bps == 0) return 0;
    return (amount * bps) / MAX_BPS;
}

function beforeBps(uint amount, uint16 bps) pure returns (uint) {
    if (amount == 0 || bps == 0) return 0;
    return (amount * MAX_BPS) / (MAX_BPS + bps);
}

function routeSchema1(string memory maybeRoute, string memory a) pure returns (string memory) {
    return string.concat(bytes(maybeRoute).length == 0 ? ROUTE_EMPTY : maybeRoute, ">", a);
}

function routeSchema2(string memory maybeRoute, string memory a, string memory b) pure returns (string memory) {
    return string.concat(bytes(maybeRoute).length == 0 ? ROUTE_EMPTY : maybeRoute, ">", a, ">", b);
}
