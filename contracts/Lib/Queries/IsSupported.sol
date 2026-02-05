// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Node} from "../Node.sol";

string constant ABI = "function isSupported(uint[] ids) external view returns (bool[])";
bytes4 constant SELECTOR = IIsSupported.isSupported.selector;

interface IIsSupported {
    function isSupported(uint[] calldata ids) external view returns (bool[] memory);
}

abstract contract IsSupported is IIsSupported, Node {
    constructor() {
        emit Query(nodeId, toEid(SELECTOR), 0, ABI);
    }

    function isSupported(uint id) internal view virtual returns (bool);

    function isSupported(uint[] calldata ids) external view returns (bool[] memory) {
        bool[] memory result = new bool[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            result[i] = isSupported(ids[i]);
        }
        return result;
    }
}
