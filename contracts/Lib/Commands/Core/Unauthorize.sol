// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function unauthorize(uint account, bytes step) external payable returns (bytes32, bytes)";
string constant REQ = "unauthorize(address[] blacklist)";
bytes4 constant SELECTOR = IUnauthorize.unauthorize.selector;

interface IUnauthorize {
    function unauthorize(uint account, bytes calldata step) external payable returns (bytes32, bytes memory);
}

abstract contract Unauthorize is IUnauthorize, Command {
    constructor() {
        emit Endpoint(hostId, toEid(true, SELECTOR), 0, ABI, REQ);
    }

    function unauthorize(
        uint account,
        bytes calldata step
    ) external payable onlyAdmin(account) returns (bytes32, bytes memory) {
        address[] memory list = abi.decode(getRequest(step), (address[]));
        for (uint i = 0; i < list.length; i++) {
            access(list[i], false);
        }
        return done();
    }
}
