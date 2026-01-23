// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

uint16 constant DENOMINATOR = 10_000;

// step: endpoint:value:req:?(validator:deadline:from:sig)

error ValueOverflow();
error ZeroAddr();

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

/* function chainId() view returns (uint32) {
    return uint32(max32(block.chainid));
}
 */
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

/* function pack(value, bounty) {
    // Pack: shift value left 160 bits, then OR with bounty
    return (max96(value) << 160n) | max160(bounty);
}

// Helper functions that throw if values exceed bit limits
function max96(value) {
    const MAX_96 = (1n << 96n) - 1n; // 2^96 - 1
    const val = BigInt(value);
    if (val > MAX_96) {
        throw new Error(`Value overflow: ${val} exceeds maximum ${MAX_96}`);
    }
    return val;
}

function max160(value) {
    const MAX_160 = (1n << 160n) - 1n; // 2^160 - 1
    const val = BigInt(value);
    if (val > MAX_160) {
        throw new Error(`Value overflow: ${val} exceeds maximum ${MAX_160}`);
    }
    return val;
}

// Usage:
try {
    const msgValue = 1000000000000000000n; // 1 ETH in wei
    const bountyAmount = 5000000000000000000000n; // 5000 tokens
    
    const packed = pack(msgValue, bountyAmount);
    console.log(packed.toString());
} catch (error) {
    console.error(error.message);
} */
