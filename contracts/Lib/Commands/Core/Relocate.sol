// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";
import {resolveAmount, anyAddr} from "../../Utils.sol";

string constant ABI = "function relocate(uint account, bytes step) external payable returns (bytes4, bytes)";
string constant REQ = "relocate(address to, uint min, uint max)";
bytes4 constant SELECTOR = IRelocate.relocate.selector;

struct RelocateRequest {
    address to;
    uint min;
    uint max;
}

interface IRelocate {
    function relocate(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Relocate is IRelocate, Command {
    constructor() {
        emit Endpoint(hostId, toEid(SELECTOR), 0, ABI, REQ);
    }

    function decodeRelocate(bytes calldata step) private pure returns (RelocateRequest memory q) {
        (q.to, q.min, q.max) = abi.decode(getRequest(step), (address, uint, uint));
    }

    function relocate(
        uint account,
        bytes calldata step
    ) external payable onlyAdmin(account) returns (bytes4, bytes memory) {
        RelocateRequest memory q = decodeRelocate(step);
        callTo(q.to, resolveAmount(address(this).balance, q.min, q.max), "");
        return done();
    }
}
