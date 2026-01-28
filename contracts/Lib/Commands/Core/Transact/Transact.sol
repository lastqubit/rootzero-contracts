// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command, ITransact, Tx, TRANSACT} from "../Base.sol";

string constant ABI = "function transact(uint account, tuple(address from, address to, uint id, uint amount)[] txs, bytes step) external payable returns (bytes4, bytes)";

abstract contract Transact is ITransact, Command {
    uint internal immutable transactId = toEid(TRANSACT);

    constructor(string memory params) {
        emit Endpoint(hostId, transactId, 0, ABI, params);
    }

    function transact(
        uint account,
        Tx[] calldata txs,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
