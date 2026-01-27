// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {SETUP, OPERATE} from "../Commands/Base.sol";
import {Relay} from "../Commands/Core/Setup/Relay.sol";
import {Publish} from "../Commands/Core/Operate/Publish.sol";
import {toResumeCall} from "../Commands/Core/Entry/Resume.sol";
import {difference, resolveAmount} from "../Utils.sol";

string constant RELAY = "relay(bytes[] steps)";
string constant DISPATCH = "dispatch(bytes[] steps)";

struct DispatchRequest {
    bytes[] steps;
}

abstract contract Dispatch is Relay(RELAY), Publish(DISPATCH) {
    function toDispatchRequest(bytes calldata step) public pure returns (DispatchRequest memory) {
        return abi.decode(step, (DispatchRequest));
    }

    function publish(bytes4 head, bytes memory args, DispatchRequest memory q) internal returns (bytes4, bytes memory) {
        callTo(cmdr, 0, toResumeCall(head, args, q.steps));
        return done();
    }

    function relay(
        uint account,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return publish(SETUP, abi.encode(account, ""), toDispatchRequest(step));
    }

    function publish(
        uint account,
        uint id,
        uint amount,
        bytes calldata,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return publish(OPERATE, abi.encode(account, id, amount, "", ""), toDispatchRequest(step));
    }
}
