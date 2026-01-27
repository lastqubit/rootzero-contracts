// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../../Base.sol";

string constant ABI = "function resume(bytes4 head, bytes args, bytes[] steps) external payable returns(uint count)";
bytes4 constant SELECTOR = IResume.resume.selector;

interface IResume {
    function resume(bytes4 head, bytes memory args, bytes[] calldata steps) external payable returns (uint);
}

function toResumeCall(bytes4 head, bytes memory args, bytes[] memory steps) pure returns (bytes memory) {
    return abi.encodeCall(IResume.resume, (head, args, steps));
}

abstract contract Resume is IResume, Command {
    constructor() {
        emit Endpoint(hostId, toEid(SELECTOR), 0, ABI, "");
    }

    function resume(bytes4 head, bytes memory args, bytes[] calldata steps) external payable virtual returns (uint);
}
