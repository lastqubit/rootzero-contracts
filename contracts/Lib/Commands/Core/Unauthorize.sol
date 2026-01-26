// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";
import {anyAddr} from "../../Utils.sol";

string constant ABI = "function unauthorize(uint account, bytes step) external payable returns (bytes4, bytes)";
string constant REQ = "unauthorize(uint[] hosts)";
bytes4 constant SELECTOR = IUnauthorize.unauthorize.selector;

interface IUnauthorize {
    function unauthorize(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Unauthorize is IUnauthorize, Command {
    constructor() {
        emit Endpoint(hostId, toEid(SELECTOR), 0, ABI, REQ);
    }

    function unauthorize(
        uint account,
        bytes calldata step
    ) external payable onlyAdmin(account) returns (bytes4, bytes memory) {
        uint[] memory hosts = abi.decode(getRequest(step), (uint[]));
        for (uint i = 0; i < hosts.length; i++) {
            access(anyAddr(hosts[i], true), false);
        }
        return done();
    }
}
