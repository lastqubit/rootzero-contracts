// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

// step: endpoint:value:req:?(validator:deadline:from:sig)

uint16 constant DENOMINATOR = 10_000;
uint16 constant ID = uint16(bytes2(0x0101));
uint32 constant VALUE = uint32(bytes4(0x01010100));
uint32 constant ACCOUNT = uint32(bytes4(0x01010200));
uint32 constant HOST = uint32(bytes4(0x01010300));
uint32 constant ENDPOINT = uint32(bytes4(0x01010400));
uint32 constant ASSET = uint32(bytes4(0x01010500));

uint32 constant TOKEN = ASSET | 1;

error ZeroAddr();
error ZeroAmount();
error ZeroId();
error InvalidId();
error BadAmount(uint amount);
error Nondeductible(uint amount, uint disposable);
error ValueOverflow();

struct Value {
    uint use;
    uint _disposable;
}

function msgValue() view returns (Value memory) {
    return Value({use: 0, _disposable: msg.value});
}

function build(address addr, uint32 selector, uint32 chain, uint32 head) pure returns (uint) {
    uint id = uint(uint160(addr));
    id |= uint(selector) << 160;
    id |= uint(chain) << 192;
    id |= uint(head << 224);
    return id;
}

function difference(uint a, uint b) pure returns (uint) {
    return a > b ? a - b : b - a;
}

function addrOr(address addr, address or) pure returns (address) {
    return addr == address(0) ? or : addr;
}

function zeroAddr(address addr) pure returns (bool) {
    return addr == address(0);
}

function ensureAddr(address addr) pure returns (address) {
    if (addr == address(0)) {
        revert ZeroAddr();
    }
    return addr;
}

function ensureId(uint id) pure returns (uint) {
    if (id == 0) {
        revert ZeroId();
    }
    return id;
}

function isLocal(uint id) view returns (bool) {
    return uint32(id >> 192) == block.chainid;
}

function toValueId() view returns (uint) {
    return build(address(0), 0, uint32(max32(block.chainid)), VALUE);
}

function toAccountId(address addr) pure returns (uint) {
    return build(addr, 0, 0, ACCOUNT);
}

function toHostId(address addr) view returns (uint) {
    return build(addr, 0, uint32(max32(block.chainid)), HOST);
}

function toEndpointId(address addr, bytes4 selector) view returns (uint) {
    return build(addr, uint32(selector), uint32(max32(block.chainid)), ENDPOINT);
}

function toTokenId(address addr) view returns (uint) {
    return build(addr, 0, uint32(max32(block.chainid)), TOKEN);
}

function anyAddr(uint id, bool onlyLocal) view returns (address) {
    if (uint16(id >> 240) != ID || (onlyLocal && isLocal(id))) {
        revert InvalidId();
    }
    return address(uint160(id));
}

function ensureAccount(uint id) pure returns (uint) {
    if (uint32(id >> 224) != ACCOUNT) {
        revert InvalidId();
    }
    return id;
}

function accountAddr(uint id) pure returns (address) {
    if (uint32(id >> 224) != ACCOUNT) {
        revert InvalidId();
    }
    return address(uint160(id));
}

function hostAddr(uint id, bool onlyLocal) view returns (address) {
    if (uint32(id >> 224) != HOST || (onlyLocal && isLocal(id))) {
        revert InvalidId();
    }
    return address(uint160(id));
}

function endpointAddr(uint id, bool onlyLocal) view returns (address) {
    if (uint32(id >> 224) != ENDPOINT || (onlyLocal && isLocal(id))) {
        revert InvalidId();
    }
    return address(uint160(id));
}

function tokenAddr(uint id, bool onlyLocal) view returns (address) {
    if (uint32(id >> 224) != TOKEN || (onlyLocal && isLocal(id))) {
        revert InvalidId();
    }
    return address(uint160(id));
}

function ensureAmount(uint amount) pure returns (uint) {
    if (amount == 0) {
        revert ZeroAmount();
    }
    return amount;
}

function ensureAmount(uint amount, uint min, uint max) pure returns (uint) {
    if (amount < min || amount > max) {
        revert BadAmount(amount);
    }
    return amount;
}

function resolveAmount(uint disposable, uint min, uint max) pure returns (uint) {
    uint amount = disposable > max ? max : disposable;
    if (amount < min) {
        revert BadAmount(amount);
    }
    return amount;
}

function deductFrom(uint amount, uint from) pure returns (uint) {
    if (amount > from) {
        revert Nondeductible(amount, from);
    }
    return from - amount;
}

function max32(uint value) pure returns (uint) {
    if (value > type(uint32).max) {
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

function pack(uint value, uint bounty) pure returns (uint) {
    return (max96(value) << 160) | max160(bounty);
}

function calcBps(uint amount, uint16 bps) pure returns (uint) {
    if (amount == 0 || bps == 0) return 0;
    return (amount * bps) / DENOMINATOR;
}

function reverse(uint amount, uint16 bps) pure returns (uint) {
    if (amount == 0 || bps == 0) return 0;
    return (amount * DENOMINATOR) / (DENOMINATOR + bps);
}

function encodeEntry(uint account) pure returns (bytes memory) {
    return abi.encode(account, "");
}


