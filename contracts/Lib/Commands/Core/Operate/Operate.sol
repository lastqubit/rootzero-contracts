// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command, IOperate, OPERATE} from "../Base.sol";

struct OpInput {
    uint account;
    uint id;
    uint amount;
}

function decodeOperate(bytes memory data) pure returns (OpInput memory i) {
    (i.account, i.id, i.amount) = abi.decode(data, (uint, uint, uint));
}

abstract contract Operate is IOperate, Command {
    uint internal immutable operateId = toEid(OPERATE);

    constructor(string memory params) {
        emit Step(nodeId, operateId, 0, OPERATE, params);
    }

    function operate(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
