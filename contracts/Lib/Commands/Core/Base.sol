// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../../Host.sol";
import {getBlock} from "../../Utils.sol";

bytes4 constant ADMIN = IAdmin.admin.selector;
bytes4 constant SETUP = ISetup.setup.selector;
bytes4 constant OPERATE = IOperate.operate.selector;
bytes4 constant TRANSACT = ITransact.transact.selector;
bytes4 constant PROCESS = IProcess.process.selector;

struct Tx {
    uint from;
    uint to;
    uint id;
    uint amount;
}

interface IAdmin {
    function admin(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

interface ISetup {
    function setup(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

interface IOperate {
    function operate(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

interface ITransact {
    function transact(
        uint account,
        Tx[] calldata txs,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

interface IProcess {
    function process(
        uint account,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

function done() pure returns (bytes4, bytes memory) {
    return (0, "");
}

function nextSetup(uint account) pure returns (bytes4, bytes memory) {
    return (SETUP, abi.encode(account, ""));
}

function nextOperate(uint account, uint id, uint amount) pure returns (bytes4, bytes memory) {
    return (OPERATE, abi.encode(account, id, amount, "", ""));
}

function nextTransact(uint account, Tx[] memory txs) pure returns (bytes4, bytes memory) {
    return (TRANSACT, abi.encode(account, txs, ""));
}

function nextProcess(uint account, bytes memory data) pure returns (bytes4, bytes memory) {
    return (PROCESS, abi.encode(account, data, ""));
}

function getRequest(bytes calldata step) pure returns (bytes calldata) {
    return getBlock(0, 64, step);
}

function getArgument(bytes4 key, bytes calldata step) pure returns (bytes calldata) {
    return getBlock(key, 64, step);
}

abstract contract Command is Host {
    error UnexpectedStage();
}
