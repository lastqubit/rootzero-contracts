// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

function bytes32ToString(bytes32 value) pure returns (string memory result) {
    uint len;
    while (len < 32 && value[len] != 0) {
        unchecked {
            ++len;
        }
    }

    result = new string(len);
    assembly ("memory-safe") {
        mstore(add(result, 0x20), value)
    }
}
