// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 6: Top-Level List Input
//
// A top-level `many #asset` list is published as a custom schema. Its custom
// key identifies the outer list block, whose payload is a stream of ASSET
// blocks. Multiple outer blocks still form an ordinary command batch.

import {Host} from "../contracts/Core.sol";
import {CommandBase, Cur, Decoders, Execution, Executions, Lanes, Specs} from "../contracts/Commands.sol";

using Executions for Execution;
using Decoders for Cur;

abstract contract MyCommand is CommandBase {
    string private constant INPUT = "many #asset";
    uint private immutable inputSpec = schema(1, 0, 0, 128, INPUT, bytes32(0));
    uint private immutable descriptor;

    event AssetSeen(uint indexed batch, bytes32 asset);

    constructor() {
        (, descriptor) = command("myCommand", Specs.Empty, inputSpec, Specs.Empty, 0, 0);
    }

    function myCommand(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 0);
        uint batch;

        while (exec.more()) {
            Cur memory items = exec.list(inputSpec, Lanes.Input);

            while (items.more()) {
                emit AssetSeen(batch, items.unpackAsset());
            }

            unchecked {
                ++batch;
            }
        }

        return closeCommand(exec);
    }
}

contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero) {}
}
