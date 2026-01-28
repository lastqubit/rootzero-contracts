// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command, done, getRequest} from "../Base.sol";
import {anyAddr} from "../../../Utils.sol";

string constant ABI = "function authorize(uint account, bytes step) external payable returns (bytes4, bytes)";
string constant REQ = "authorize(uint[] hosts)";
bytes4 constant AUTHORIZE = IAuthorize.authorize.selector;

interface IAuthorize {
    function authorize(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Authorize is IAuthorize, Command {
    constructor() {
        emit Endpoint(hostId, toEid(AUTHORIZE), 0, ABI, REQ);
    }

    function authorize(
        uint account,
        bytes calldata step
    ) external payable onlyAdmin(account) returns (bytes4, bytes memory) {
        uint[] memory hosts = abi.decode(getRequest(step), (uint[]));
        for (uint i = 0; i < hosts.length; i++) {
            access(anyAddr(hosts[i], true), true);
        }
        return done();
    }
}
