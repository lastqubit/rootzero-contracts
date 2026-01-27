// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Utilize} from "./Core/Operate/Utilize.sol";
import {toResumeCall} from "./Core/Entry/Resume.sol";

string constant REQ = "dispatch(bytes[] steps)";

struct DispatchRequest {
    bytes[] steps;
}

abstract contract Dispatch is Utilize(REQ) {
    function toDispatchReq(bytes calldata step) public view returns (DispatchRequest memory) {
        return abi.decode(step, (DispatchRequest));
    }

    function utilize(
        uint account,
        uint id,
        uint amount,
        bytes calldata,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {}
}
