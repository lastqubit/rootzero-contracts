// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function resume(bytes32 head, bytes body, bytes[] steps, bytes signed) external payable returns(uint count)";
bytes4 constant SELECTOR = IResume.resume.selector;

interface IResume {
    function resume(
        bytes32 head,
        bytes memory body,
        bytes[] calldata steps,
        bytes calldata signed
    ) external payable returns (uint);
}

abstract contract Resume is IResume, Command {
    constructor() {
        emit Endpoint(hostId, toEid(false, SELECTOR), 0, ABI, "");
    }

    function resume(
        bytes32 head,
        bytes memory body,
        bytes[] calldata steps,
        bytes calldata signed
    ) external payable virtual returns (uint);
}
