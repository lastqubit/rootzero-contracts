const MAX32 = (1n << 32n) - 1n; // 2^32 - 1
const MAX64 = (1n << 64n) - 1n; // 2^64 - 1
const MAX96 = (1n << 96n) - 1n; // 2^96 - 1
const MAX128 = (1n << 128n) - 1n; // 2^128 - 1
const MAX160 = (1n << 160n) - 1n; // 2^160 - 1
const MAX256 = (1n << 256n) - 1n; // 2^256 - 1

function pack(value, bounty) {
    // Pack: shift value left 160 bits, then OR with bounty
    return (max96(value) << 160n) | max160(bounty);
}

function ensureMax(value, max) {
    const val = BigInt(value);
    if (val > max) {
        throw new Error(`Value overflow: ${val} exceeds maximum ${max}`);
    }
    return val;
}

function max32(value) {
    return ensureMax(value, MAX32);
}

function max64(value) {
    return ensureMax(value, MAX64);
}

function max96(value) {
    return ensureMax(value, MAX96);
}

function max128(value) {
    return ensureMax(value, MAX128);
}

function max160(value) {
    return ensureMax(value, MAX160);
}

function max256(value) {
    return ensureMax(value, MAX256);
}
