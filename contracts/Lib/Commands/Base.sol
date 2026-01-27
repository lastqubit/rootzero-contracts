// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../Host.sol";
import {getBlock} from "../Utils.sol";

bytes4 constant ADMIN = IPipeline.admin.selector;
bytes4 constant SETUP = IPipeline.setup.selector;
bytes4 constant OPERATE = IPipeline.operate.selector;
bytes4 constant PROCESS = IPipeline.process.selector;

struct OpInput {
    uint account;
    uint id;
    uint amount;
}

function decodeOperate(bytes memory data) pure returns (OpInput memory i) {
    (i.account, i.id, i.amount) = abi.decode(data, (uint, uint, uint));
}

interface IPipeline {
    function admin(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);

    function setup(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);

    function operate(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);

    function process(
        uint account,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Command is Host {
    error UnexpectedStage();

    function done() internal pure returns (bytes4, bytes memory) {
        return (0, "");
    }

    function setup(uint account) internal pure returns (bytes4, bytes memory) {
        return (SETUP, abi.encode(account, ""));
    }

    function next(uint account, uint id, uint amount) internal pure returns (bytes4, bytes memory) {
        return (OPERATE, abi.encode(account, id, amount, "", ""));
    }

    function supply(uint account, bytes memory data) internal pure returns (bytes4, bytes memory) {
        return (PROCESS, abi.encode(account, data, ""));
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
