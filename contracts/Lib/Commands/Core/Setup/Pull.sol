// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant PULL = IPull.pull.selector;

/* Pull-based operations:

borrow → pull (pull from pool)
withdraw → pull (pull from vault)
claim → pull (pull rewards) */

interface IPull {
    function pull(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Pull is IPull, Command {
    uint internal immutable pullId = toEid(PULL);

    constructor(string memory params) {
        emit Step(nodeId, pullId, 0, PULL, params);
    }

    function pull(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
