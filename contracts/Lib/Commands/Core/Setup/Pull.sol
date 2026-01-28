// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function pull(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IPull.pull.selector;

/* Pull-based operations:

borrow → pull (pull from pool)
withdraw → pull (pull from vault)
claim → pull (pull rewards) */

interface IPull {
    function pull(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Pull is IPull, Command {
    uint internal immutable pullId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, pullId, 0, ABI, params);
    }

    function pull(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
