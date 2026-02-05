// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command, ITransact, Tx, TRANSACT} from "../Base.sol";

abstract contract Transact is ITransact, Command {
    uint internal immutable transactId = toEid(TRANSACT);

    constructor(string memory params) {
        emit Step(nodeId, transactId, 0, TRANSACT, params);
    }

    function transact(
        uint account,
        Tx[] calldata txs,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
