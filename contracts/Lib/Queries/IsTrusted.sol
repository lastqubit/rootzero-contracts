// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Node} from "../Node.sol";
import {nodeAddr} from "../Utils.sol";

string constant ABI = "function isTrusted(uint caller) external view returns (bool)";
bytes4 constant SELECTOR = IIsTrusted.isTrusted.selector;

interface IIsTrusted {
    function isTrusted(uint caller) external view returns (bool);
}

abstract contract IsTrusted is IIsTrusted, Node {
    constructor() {
        emit Query(nodeId, toEid(SELECTOR), 0, ABI);
    }

    function isTrusted(uint caller) external view returns (bool) {
        return isTrusted(nodeAddr(caller, true));
    }
}
