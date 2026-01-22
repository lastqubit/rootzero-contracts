// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

// @dev returns zero on out of bounds instead of revert.

bytes32 constant MASK4 = 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000;

function slice4(bytes calldata data, uint offset) pure returns (bytes4 result) {
    assembly {
        if lt(add(offset, 4), add(data.length, 1)) {
            result := calldataload(add(data.offset, offset))
        }
    }
}

function compare4(bytes calldata data, uint offset, bytes4 target) pure returns (bool equal) {
    assembly {
        if iszero(gt(offset, sub(data.length, 4))) {
            equal := eq(and(calldataload(add(data.offset, offset)), MASK4), target)
        }
    }
}

library Data {
    bytes1 constant SIGNED = bytes1(uint8(5));
        //uint8 internal constant SIGNED = 5;

    error BadData();

    function oob(uint size, uint o, bytes calldata data) private pure returns (bool) {
        return o + size > data.length;
    }

    function noob(uint size, uint no, bytes calldata data) private pure returns (bool) {
        return no < size || no > data.length;
    }

    function to1(bytes calldata data, uint o) internal pure returns (bytes1) {
        return oob(1, o, data) ? bytes1(0) : bytes1(data[o:o + 1]);
    }

    function to2(bytes calldata data, uint o) internal pure returns (bytes2) {
        return oob(2, o, data) ? bytes2(0) : bytes2(data[o:o + 2]);
    }

    function to4(bytes calldata data, uint o) internal pure returns (bytes4) {
        return oob(4, o, data) ? bytes4(0) : bytes4(data[o:o + 4]);
    }

    function to8(bytes calldata data, uint o) internal pure returns (bytes8) {
        return oob(8, o, data) ? bytes8(0) : bytes8(data[o:o + 4]);
    }

    function to20(bytes calldata data, uint o) internal pure returns (bytes20) {
        return oob(20, o, data) ? bytes20(0) : bytes20(data[o:o + 20]);
    }

    function to32(bytes calldata data, uint o) internal pure returns (bytes32) {
        return oob(32, o, data) ? bytes32(0) : bytes32(data[o:o + 32]);
    }

    function to1no(bytes calldata data, uint no) internal pure returns (bytes1) {
        if (noob(1, no, data)) return 0;
        uint o = data.length - no;
        return bytes1(data[o:o + 1]);
    }

    function to2no(bytes calldata data, uint no) internal pure returns (bytes2) {
        if (noob(2, no, data)) return 0;
        uint o = data.length - no;
        return bytes2(data[o:o + 2]);
    }

    function to4no(bytes calldata data, uint no) internal pure returns (bytes4) {
        if (noob(4, no, data)) return 0;
        uint o = data.length - no;
        return bytes4(data[o:o + 4]);
    }

    function to8no(bytes calldata data, uint no) internal pure returns (bytes8) {
        if (noob(8, no, data)) return 0;
        uint o = data.length - no;
        return bytes8(data[o:o + 8]);
    }

    function to20no(bytes calldata data, uint no) internal pure returns (bytes20) {
        if (noob(20, no, data)) return 0;
        uint o = data.length - no;
        return bytes20(data[o:o + 20]);
    }

    function to32no(bytes calldata data, uint no) internal pure returns (bytes32) {
        if (noob(32, no, data)) return 0;
        uint o = data.length - no;
        return bytes32(data[o:o + 32]);
    }

    function eq2(bytes calldata data, bytes2 eq, uint o) internal pure returns (bool) {
        return !oob(2, o, data) && eq == bytes2(data[o:o + 2]);
    }

    function eq20(bytes calldata data, bytes20 eq, uint o) internal pure returns (bool) {
        return !oob(20, o, data) && eq == bytes20(data[o:o + 20]);
    }

    function eq32(bytes calldata data, bytes32 eq, uint o) internal pure returns (bool) {
        return !oob(32, o, data) && eq == bytes32(data[o:o + 32]);
    }

    function ensure32(bytes calldata data, bytes32 eq, uint o) internal pure returns (bytes calldata) {
        if (eq32(data, eq, o) == false) {
            revert BadData();
        }
        return data;
    }

    function toBlock(bytes calldata blocks, bytes2 cat) internal pure returns (bytes calldata) {
        uint16 len;
        for (uint o = 0; (len = uint16(to2(blocks, o))) > 0; ) {
            if (eq2(blocks, cat, o + 2)) {
                return blocks[o + 4:o + len - 6];
            }
            o += len;
        }
        return blocks[0:0];
    }

    function head(bytes calldata data) internal pure returns (uint) {
        return uint(bytes32(data));
    }

    function meta(bytes calldata data) internal pure returns (uint) {
        return uint(to32(data, 32));
    }

    function from(bytes calldata data) internal pure returns (address) {
        return address(to20(data, 44));
    }

    function signed(bytes calldata data) internal pure returns (bool) {
        return SIGNED == to1no(data, 129); //??
    }
}

/*     bytes1 constant SIGNED = bytes1(Head.SIGNED);

    error ZeroBytes();
    error BadBytes(); // ??

    function void(bytes calldata data) internal pure returns (bool) {
        return data.length == 0;
    }

    function head(bytes calldata data) internal pure returns (uint) {
        return uint(bytes32(data));
    }

    function signed(bytes calldata data) internal pure returns (bool) {
        return bytes1(data) == SIGNED;
    }

    function ensure(
        bytes calldata data
    ) internal pure returns (bytes calldata) {
        if (data.length == 0) {
            revert ZeroBytes();
        }
        return data;
    }

    function ensure(
        bytes calldata data,
        uint min,
        uint max
    ) internal pure returns (bytes calldata) {
        if (data.length < min || data.length > max) {
            revert BadBytes();
        }
        return data;
    }

    function version(bytes calldata data) internal pure returns (uint8) {
        return uint8(bytes1(data));
    }

    function meta(bytes calldata data) internal pure returns (uint) {
        return uint(bytes32(data[32:64]));
    }

    function addr(bytes calldata data) internal pure returns (address) {
        return address(bytes20(data[12:32]));
    }

    function from(bytes calldata data) internal pure returns (address) {
        return address(bytes20(data[44:64]));
    }

         function signer(bytes calldata data) internal pure returns (address) {
        return address(bytes20(data[108:128]));
    } 

    function value(bytes calldata data) internal pure returns (uint96) {
        return uint96(bytes12(data[32:44]));
    } */
