// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Keys, Writer, Writers} from "../Cursors.sol";
import {QueryBase} from "../queries/Base.sol";

using Cursors for Cur;
using Writers for Writer;

string constant INPUT = "uint foo";
string constant OUTPUT = "uint bar";

contract TestQuery is QueryBase {
    string private constant NAME = "incrementQuery";
    uint public immutable incrementQueryId = queryId(NAME);

    constructor() {
        emit Query(host, incrementQueryId, NAME, "1:1", INPUT, OUTPUT);
    }

    function incrementQuery(bytes calldata request) external pure returns (bytes memory out) {
        (Cur memory input, uint groups) = Cursors.first(request, 1);
        Writer memory writer = Writers.alloc32s(groups);

        while (input.i < input.len) {
            uint foo = uint(input.unpack32(Keys.Data));
            writer.appendBlock32(Keys.Data, bytes32(foo + 1), 32);
        }

        input.complete();
        out = writer.finish();
    }
}
