// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import "hardhat/console.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Node} from "../Lib/Node.sol";
import {Validator} from "../Lib/Validation/Validator.sol";
import {Value} from "../Lib/Utils.sol";
import {isNext, isEntry} from "../Lib/Utils/Command.sol";
import {Endpoints} from "./Endpoints.sol";

abstract contract Executor is Ownable, Node, Endpoints, Validator {
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
        bytes memory data = abi.encode(steps, executeId, deadline);
        return validateRecover(data, signed);
    }

    function encodeCall(
        bytes4 selector,
        bytes memory args,
        bytes calldata step
    ) private pure returns (bytes memory result) {
        assembly {
            let s := step.length
            let argsLen := mload(args)
            let argsToCopy := sub(argsLen, 0x20)
            let size := add(add(4, argsLen), s)

            result := mload(0x40)

            mstore(0x40, add(result, and(add(add(0x20, size), 0x1f), not(0x1f))))
            mstore(result, size)

            let ptr := add(result, 0x20)
            mstore8(ptr, byte(0, selector))
            mstore8(add(ptr, 1), byte(1, selector))
            mstore8(add(ptr, 2), byte(2, selector))
            mstore8(add(ptr, 3), byte(3, selector))

            // Copy args except last 32 bytes (the zero length) using mcopy
            mcopy(add(result, 0x24), add(args, 0x20), argsToCopy)

            // Copy step length and data at the position where the zero was
            let stepPos := add(add(result, 0x24), argsToCopy)
            calldatacopy(stepPos, step.offset, add(s, 0x20))
        }
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

    function callEndpoint(uint eid, bytes memory call, Value memory value) private returns (bytes4, bytes memory) {
        bytes4 selector;
        value.use = 0;
        // check eid for open flag to encoded (account, step)
    }

    function next(
        bytes4 selector,
        bytes memory args,
        bytes calldata step,
        Value memory value
    ) private returns (bytes4, bytes memory) {
        uint eid;
        if (eid == initiateId) return debitFrom(args, step);
        if (eid == resolveId) return creditTo(args, step);
        bytes memory call = encodeCall(selector, args, step);
        return callEndpoint(eid, call, value);
    }

    function pipe(bytes4 head, bytes memory args, bytes[] calldata steps, Value memory v) internal returns (uint) {
        for (uint i = 0; i < steps.length; i++) {
            // auth not return eid auth(head, steps[i])
            (head, args) = next(0, args, steps[i], v);
            if (head == 0) return i + 1;
        }
        creditTo(args, msg.data[0:0]); // ensure head is next..
        return steps.length + 1;
    }
}
