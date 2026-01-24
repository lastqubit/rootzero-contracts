// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import "hardhat/console.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Node} from "../Lib/Node.sol";
import {Validator} from "../Lib/Validator.sol";
import {Call, Value, useValue, encodeCall} from "../Lib/Call.sol";
import {Id} from "../Lib/Id.sol";
import {isNext, isEntry} from "../Lib/Utils/Command.sol";
import {Endpoints} from "./Endpoints.sol";

abstract contract Executor is Ownable, Node, Endpoints, Validator {
    using Call for bytes4;

    error BadPipe();
    error InvalidBody();

    // check eid... use eid open flag
    function auth(bytes4 head, bytes calldata step) private returns (uint) {


        // open utilize step to resolve account
        // head utilize -> accept step resolve/finalize
        return uint(bytes32(step));
    }

    // only allow input from guardians... not from owner.
    // validate max steps
    // validate factors on dst endpoint...
    // validator id can be endpoint id ??.. seperate validator for each endpoint
    // signed must include signer address as 32 bytes.. cross chain
    function validate(bytes[] calldata steps, bytes calldata signed) internal view returns (address) {
        if (signed.length == 0) {
            return msg.sender;
        }
        uint64 deadline;
        bytes memory data = abi.encode(executeId, deadline, steps);
        return validateRecover(data, signed);
    }

    function encodeEntry(uint account) internal pure returns (bytes memory) {
        return abi.encode(account, "");
    }

    /*     function callTo(
        uint eid,
        uint head,
        bytes memory args,
        bytes calldata step,
        Value memory total
    ) internal returns (bytes4, bytes memory) {
        uint v = uint96(bytes12(step[32:44]));
        address addr = address(uint160(eid));
        bytes memory call; // = encodeCall(head, args, step);
        return abi.decode(callTo(addr, v, total, call), (uint, bytes));
    } */

    /*     function toCall(
        uint eid,
        bytes memory args,
        bytes calldata step
    ) private pure returns (bytes memory call) {
        console.log("EID %s", eid);
        uint32 selector = uint32(eid >> 216);
        console.log("SELECT %s", selector);
        call = bytes.concat(bytes4(selector), args, step);
        call.store32no(step.length + 32, step.length);
    } */

    /*     function call(
        address addr,
        uint value,
        Value memory total,
        bytes memory data
    ) private returns (bytes4, bytes memory) {
        return abi.decode(callTo(addr, value, total, data), (uint, bytes));
    } */

    /*     function call(
        uint eid,
        bytes memory call,
        bytes calldata step,
        Value memory value
    ) private returns (bytes4, bytes memory) {
        address addr = step.addr();
        uint v;
        return abi.decode(callTo(addr, v, value, call), (uint, bytes));
    } */

    /*     function toCall(
        uint from,
        bytes calldata step
    ) private pure returns (bytes memory) {
        bytes4 selector = step.selector();
        return bytes.concat(selector, abi.encode(from, step));
    } */

    function executeEndpoint(
        uint eid,
        bytes memory args,
        bytes calldata step,
        Value memory value
    ) private returns (bytes4, bytes memory) {
        bytes4 selector;
        encodeCall(selector, args, step);
        // check eid for open flag to encoded (account, step)
    }

    function next(
        uint eid,
        bytes memory args,
        bytes calldata step,
        Value memory value
    ) private returns (bytes4, bytes memory) {
        if (eid == initiateId) return debitFrom(args, step);
        if (eid == resolveId) return creditTo(args, step);
        return executeEndpoint(eid, args, step, value);
    }

    function pipe(bytes4 head, bytes memory args, bytes[] calldata steps, Value memory v) internal returns (uint) {
        for (uint i = 0; i < steps.length; i++) {
            // auth not return eid
            (head, args) = next(auth(head, steps[i]), args, steps[i], v);
            if (head == 0) return i + 1;
        }
        creditTo(args, msg.data[0:0]); // ensure head is next..
        return steps.length + 1;
    }
}
