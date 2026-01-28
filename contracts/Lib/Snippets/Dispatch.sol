// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {done, SETUP, OPERATE} from "../Commands/Core/Base.sol";
import {Setup} from "../Commands/Core/Setup/Setup.sol";
import {Relay} from "../Commands/Core/Operate/Relay.sol";
import {toResumeCall} from "../Commands/Core/Entry/Resume.sol";
import {difference, resolveAmount} from "../Utils.sol";

string constant REQ = "setup(bytes[] steps)";
string constant DISPATCH = "dispatch(bytes[] steps)";

struct DispatchRequest {
    bytes[] steps;
}

// add process to send payload directly ??

abstract contract Dispatch is Setup(REQ), Relay(DISPATCH) {
    function toDispatchRequest(bytes calldata step) public pure returns (DispatchRequest memory) {
        return abi.decode(step, (DispatchRequest));
    }

    function publish(bytes4 head, bytes memory args, DispatchRequest memory q) internal returns (bytes4, bytes memory) {
        callAddr(cmdr, 0, toResumeCall(head, args, q.steps));
        return done();
    }

    function setup(
        uint account,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return publish(SETUP, abi.encode(account, ""), toDispatchRequest(step));
    }

    function relay(
        uint account,
        uint id,
        uint amount,
        bytes calldata,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return publish(OPERATE, abi.encode(account, id, amount, "", ""), toDispatchRequest(step));
    }
}
