// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import "hardhat/console.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Host} from "../Lib/Host.sol";
import {Value, endpointAddr} from "../Lib/Utils.sol";
import {canAdvance} from "../Lib/Snippets/Commander.sol";
import {Endpoints} from "./Endpoints.sol";

abstract contract Executor is Ownable, Host, Endpoints {
    error PipelineAdvanceError();

    function ensureAdvanceable(bytes4 head, bytes calldata step) private pure returns (uint, bytes4) {
        bytes4 selector = bytes4(step);
        if (canAdvance(head, selector) == false) {
            revert PipelineAdvanceError();
        }
        return (uint(bytes32(step)), selector);
    }

    function ensureOperate(bytes4 head) private pure {
        /*     if (isOperate(head) == false) {
        revert PipelineAdvanceError();
    } */
    }

    // @dev args must end with step placeholder(empty bytes array)!
    function callAddr(
        address addr,
        bytes4 selector,
        bytes memory args,
        bytes calldata step,
        Value memory value
    ) private returns (bytes4, bytes memory) {
        require(args.length > 32);
        uint v = 0; // Not using values for the time being.
        assembly {
            mstore(add(add(args, 32), sub(mload(args), 32)), step.length)
        }
        return abi.decode(callAddr(addr, v, bytes.concat(selector, args, step)), (bytes4, bytes));
    }

    function next(
        bytes4 head,
        bytes memory args,
        bytes calldata step,
        Value memory value
    ) private returns (bytes4, bytes memory) {
        (uint eid, bytes4 selector) = ensureAdvanceable(head, step);
        if (eid == setupId) return debitFrom(args, step);
        if (eid == resolveId) return creditTo(args, step);
        if (eid == transactId) return settle(args, step);
        address addr = endpointAddr(eid, true);
        return callAddr(addr, selector, args, step, value);
    }

    function pipe(
        bytes4 head,
        bytes memory args,
        bytes[] calldata steps,
        Value memory value
    ) internal returns (uint count) {
        uint len = steps.length;
        for (uint i = 0; i < len; i++) {
            (head, args) = next(head, args, steps[i], value);
            if (head == 0) return i + 1;
        }
        creditTo(head, args);
        return len + 1;
    }
}
