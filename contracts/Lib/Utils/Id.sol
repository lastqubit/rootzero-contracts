// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {max32} from "./Utils.sol";

// @dev bytes4(EVM=1,ID=1,TYPE,SUB)

library Id {
    uint16 internal constant ID = uint16(bytes2(0x0101));
    uint32 internal constant VALUE = uint32(bytes4(0x01010100));
    uint32 internal constant ACCOUNT = uint32(bytes4(0x01010200));
    uint32 internal constant HOST = uint32(bytes4(0x01010300));
    uint32 internal constant ENDPOINT = uint32(bytes4(0x01010400));
    uint32 internal constant ASSET = uint32(bytes4(0x01010500));

    uint32 internal constant TOKEN = ASSET | 1;

    error ZeroId();
    error InvalidId();

    function build(address addr, uint32 selector, uint32 desc) private view returns (uint) {
        uint id = uint(uint160(addr));
        id |= uint(selector) << 160;
        id |= uint(max32(block.chainid)) << 192;
        id |= uint(desc << 224);
        return id;
    }

    function ensure(uint id) internal pure returns (uint) {
        if (id == 0) {
            revert ZeroId();
        }
        return id;
    }

    function value() internal view returns (uint) {
        return build(address(0), 0, VALUE);
    }

    function account(address addr) internal view returns (uint) {
        return build(addr, 0, ACCOUNT);
    }

    function host(address addr) internal view returns (uint) {
        return build(addr, 0, HOST);
    }

    function endpoint(address addr, bytes4 selector) internal view returns (uint) {
        return build(addr, uint32(selector), ENDPOINT);
    }

    function token(address addr) internal view returns (uint) {
        return build(addr, 0, TOKEN);
    }

    function anyAddr(uint id) internal pure returns (address) {
        if (uint16(id >> 240) != ID) {
            revert InvalidId();
        }
        return address(uint160(id));
    }

    function accountAddr(uint id, bool onlyLocal) internal view returns (address) {
        if (uint32(id >> 224) != ACCOUNT || (onlyLocal && uint32(id >> 192) != block.chainid)) {
            revert InvalidId();
        }
        return address(uint160(id));
    }

    function hostAddr(uint id, bool onlyLocal) internal view returns (address) {
        if (uint32(id >> 224) != HOST || (onlyLocal && uint32(id >> 192) != block.chainid)) {
            revert InvalidId();
        }
        return address(uint160(id));
    }

    function endpointAddr(uint id, bool onlyLocal) internal view returns (address) {
        if (uint32(id >> 224) != ENDPOINT || (onlyLocal && uint32(id >> 192) != block.chainid)) {
            revert InvalidId();
        }
        return address(uint160(id));
    }

    function tokenAddr(uint id, bool onlyLocal) internal view returns (address) {
        if (uint32(id >> 224) != TOKEN || (onlyLocal && uint32(id >> 192) != block.chainid)) {
            revert InvalidId();
        }
        return address(uint160(id));
    }
}
