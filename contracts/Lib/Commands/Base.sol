// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../Host.sol";
import {Value, useValue} from "../Utils/Value.sol";

bytes4 constant NEXT = INext.next.selector;

struct NextInput {
    uint account;
    uint id;
    uint amount;
    bytes data;
    bytes step;
}

interface INext {
    function open(
        uint account,
        bytes calldata step
    ) external payable returns (bytes32, bytes memory);

    function next(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes32, bytes memory);
}

function decodeNext(bytes memory data) pure returns (NextInput memory i) {
    (i.account, i.id, i.amount, i.data, i.step) = abi.decode(
        data,
        (uint, uint, uint, bytes, bytes)
    );
}

/* function encodeNext(
    uint account,
    uint id,
    uint amount,
    bytes memory data
) pure returns (bytes32, bytes memory) {
    return (NEXT, abi.encode(account, id, amount, data, ""));
}
 */
// @dev open endpoint = user can use endpoint as entry point
abstract contract Command is Host {
    error UnexpectedStage();

    function done() internal pure returns (bytes32, bytes memory) {
        return (0, "");
    }

    function next(
        uint account,
        uint id,
        uint amount
    ) internal pure returns (bytes32, bytes memory) {
        return (NEXT, abi.encode(account, id, amount, "", ""));
    }

    function ensureValidStage(uint eid, bytes calldata step) internal pure {
        if (eid != uint(bytes32(step))) {
            revert UnexpectedStage();
        }
    }

    function getRequest(
        bytes calldata step
    ) internal pure returns (bytes calldata) {
        return step[64:];
    }
}
