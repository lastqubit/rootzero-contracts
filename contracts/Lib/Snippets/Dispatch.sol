// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {SETUP, OPERATE} from "../Commands/Base.sol";
import {Initiate} from "../Commands/Core/Initiate.sol";
import {Utilize} from "../Commands/Core/Utilize.sol";
import {toResumeCall} from "../Commands/Entry/Resume.sol";
import {difference, resolveAmount} from "../Utils.sol";

string constant RELAY = "relay(bytes[] steps)";
string constant DISPATCH = "dispatch(bytes[] steps)";

struct DispatchRequest {
    bytes[] steps;
}

abstract contract Dispatch is Initiate(RELAY), Utilize(DISPATCH) {
    function toDispatchRequest(bytes calldata step) public pure returns (DispatchRequest memory) {
        return abi.decode(step, (DispatchRequest));
    }

    function publish(bytes4 head, bytes memory args, DispatchRequest memory q) internal returns (bytes4, bytes memory) {
        callTo(cmdr, 0, toResumeCall(head, args, q.steps));
        return done();
    }

    function initiate(
        uint account,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return publish(SETUP, abi.encode(account, ""), toDispatchRequest(step));
    }

    function utilize(
        uint account,
        uint id,
        uint amount,
        bytes calldata,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return publish(OPERATE, abi.encode(account, id, amount, "", ""), toDispatchRequest(step));
    }
}
