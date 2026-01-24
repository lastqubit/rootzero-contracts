// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Query} from "./Base.sol";
import {Id} from "../Id.sol";

string constant ABI = "function isTrusted(uint caller) external view returns (bool)";
bytes4 constant SELECTOR = IIsTrusted.isTrusted.selector;

interface IIsTrusted {
    function isTrusted(uint caller) external view returns (bool);
}

abstract contract IsTrusted is IIsTrusted, Query {
    constructor() {
        emit Endpoint(hostId, toEid(SELECTOR), 0, ABI, "");
    }

    function isTrusted(uint caller) external view returns (bool) {
        return isTrusted(Id.hostAddr(caller, true));
    }
}
