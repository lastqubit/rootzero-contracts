// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cursors, Cursor } from "../Cursors.sol";

using Cursors for Cursor;

abstract contract EachInput {
    function eachInput(Cursor memory input) internal virtual;

    function forEachInput(bytes calldata blocks, uint i) internal returns (uint) {
        (Cursor memory inputs, ) = Cursors.openInput(blocks, i);
        while (inputs.i < inputs.end) {
            eachInput(inputs.take());
        }
        return inputs.next;
    }
}




