// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../Host.sol";
import {getBlock} from "../Call.sol";

bytes4 constant ADMIN = IPipeline.admin.selector;
bytes4 constant ENTRY = IPipeline.entry.selector;
bytes4 constant NEXT = IPipeline.next.selector;

struct NextInput {
    uint account;
    uint id;
    uint amount;
}

function decodeNext(bytes memory data) pure returns (NextInput memory i) {
    (i.account, i.id, i.amount) = abi.decode(data, (uint, uint, uint));
}

interface IPipeline {
    function admin(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);

    function entry(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);

    function next(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Command is Host {
    error UnexpectedStage();

    function done() internal pure returns (bytes4, bytes memory) {
        return (0, "");
    }

    function next(uint account, uint id, uint amount) internal pure returns (bytes4, bytes memory) {
        return (NEXT, abi.encode(account, id, amount, "", ""));
    }

    function ensureValidStage(uint eid, bytes calldata step) internal pure {
        if (eid != uint(bytes32(step))) {
            revert UnexpectedStage();
        }
    }

    function getRequest(bytes calldata step) internal pure returns (bytes calldata) {
        return getBlock(0, 64, step);
    }

    function getArgument(bytes4 key, bytes calldata step) internal pure returns (bytes calldata) {
        return getBlock(key, 64, step);
    }
}
