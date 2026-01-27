// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command, IOperate, OPERATE} from "../../Base.sol";

string constant ABI = "function operate(uint account, uint id, uint amount, bytes data, bytes step) external payable returns (bytes4, bytes)";

struct OpInput {
    uint account;
    uint id;
    uint amount;
}

function decodeOperate(bytes memory data) pure returns (OpInput memory i) {
    (i.account, i.id, i.amount) = abi.decode(data, (uint, uint, uint));
}

abstract contract Operate is IOperate, Command {
    uint internal immutable operateEid = toEid(OPERATE);

    constructor(string memory params) {
        emit Endpoint(hostId, operateEid, 0, ABI, params);
    }

    function operate(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
