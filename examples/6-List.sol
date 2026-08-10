// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 6: List Blocks
//
// `many #asset` means: one LIST block whose payload is a stream of ASSET blocks.
// That does not change the top-level input model: inputs are still batches of
// top-level blocks. So a command with INPUT = `many #asset` accepts:
//
//   LIST(asset, asset, ...)
//   LIST(asset, ...)
//   LIST(asset, asset, asset, ...)
//
// as one batch input containing three list items.
//
// This example shows both layers explicitly:
// - the outer loop walks the top-level batch of LIST blocks
// - the inner loop walks the ASSET blocks inside one list item
// - the command emits one event per ASSET item, so the behavior is easy to test

import {Host} from "../contracts/Core.sol";
import {CommandBase, Cur, Decoders, Execution, Executions, Lanes, Specs} from "../contracts/Commands.sol";

using Executions for Execution;
using Decoders for Cur;
using Specs for uint;

// Off-chain schema metadata may describe this list as:
//
//   many #asset
//
// means "one LIST block whose payload is a repeated stream of ASSET blocks".
// The input can still batch multiple such LIST blocks at the top level.

abstract contract MyCommand is CommandBase {
    uint private immutable descriptor;
    event AssetSeen(uint indexed i, bytes32 asset);

    constructor() {
        (, descriptor) = command("myCommand", Specs.Empty, Specs.Asset.many(), Specs.Empty, 0, false, false);
    }

    function myCommand(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);
        uint i;

        // INPUT publishes one list item descriptor, but the input is still a
        // top-level batch. Each iteration here consumes one LIST block and
        // emits one event for every ASSET block inside that list.
        while (exec.more()) {
            Cur memory items = exec.list(Lanes.Input);

            while (items.more()) {
                bytes32 asset = items.unpackAsset();
                emit AssetSeen(i, asset);
            }

            unchecked {
                ++i;
            }
        }

        return close(exec, account);
    }
}

// Concrete host so the example can be deployed and the command can be called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero) {}
}
