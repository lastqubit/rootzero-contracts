// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cursors, Cur } from "../Cursors.sol";

using Cursors for Cur;

abstract contract EachInput {
    function eachInput(Cur memory input) internal virtual;

    function forEachInput(bytes calldata blocks, uint i) internal returns (uint) {
        (Cur memory inputs, , ) = Cursors.init(blocks[i:], 1);
        while (inputs.i < inputs.bound) {
            eachInput(inputs);
        }
        return i + inputs.bound;
    }
}





