// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function authorize(uint account, bytes step) external payable returns (bytes32, bytes)";
string constant REQ = "authorize(address[] blacklist)";
bytes4 constant SELECTOR = IAuthorize.authorize.selector;

interface IAuthorize {
    function authorize(uint account, bytes calldata step) external payable returns (bytes32, bytes memory);
}

abstract contract Authorize is IAuthorize, Command {
    constructor() {
        emit Endpoint(hostId, toEid(true, SELECTOR), 0, ABI, REQ);
    }

    function authorize(
        uint account,
        bytes calldata step
    ) external payable onlyAdmin(account) returns (bytes32, bytes memory) {
        address[] memory list = abi.decode(getRequest(step), (address[]));
        for (uint i = 0; i < list.length; i++) {
            access(list[i], true);
        }
        return done();
    }
}
