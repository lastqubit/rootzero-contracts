// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function transact(tuple(uint from, uint to, uint id, uint amount)[] txs, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = ITransact.transact.selector;

struct Tx {
    uint from;
    uint to;
    uint id;
    uint amount;
}

interface ITransact {
    function transact(Tx[] calldata txs, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Transact is ITransact, Command {
    uint internal immutable transactId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, transactId, 0, ABI, params);
    }

    function transact(Tx[] calldata txs, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
