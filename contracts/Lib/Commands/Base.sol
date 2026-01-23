// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../Host.sol";
import {Call, Value, useValue} from "../Utils/Call.sol";

/*
In Utils/Command.sol
implement a function that takes two params: bytes4 head and bytes4 step
if head == NEXT step needs to be match one of the next type commands.
if head == ENTRY step needs to be match one of the entry type commands.
else head needs to equal step.
*/

bytes4 constant ENTRY = IResponse.entry.selector;
bytes4 constant NEXT = IResponse.next.selector;

struct NextInput {
    uint account;
    uint id;
    uint amount;
}

interface IResponse {
    function entry(uint account, bytes calldata step) external payable returns (bytes32, bytes memory);

    function next(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes32, bytes memory);
}

function decodeNext(bytes memory data) pure returns (NextInput memory i) {
    (i.account, i.id, i.amount) = abi.decode(data, (uint, uint, uint));
}

// @dev open endpoint = user can use endpoint as entry point
abstract contract Command is Host {
    function done() internal pure returns (bytes32, bytes memory) {
        return (0, "");
    }

    function next(uint account, uint id, uint amount) internal pure returns (bytes32, bytes memory) {
        return (NEXT, abi.encode(account, id, amount, "", ""));
    }

    function getRequest(bytes calldata step) internal pure returns (bytes calldata) {
        return Call.getParam(0, 64, step);
    }
}
