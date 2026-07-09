// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 6: List Blocks
//
// `many #asset` means: one LIST block whose payload is a stream of ASSET blocks.
// That does not change the top-level request model: requests are still batches of
// top-level blocks. So a command with INPUT = `many #asset` accepts:
//
//   LIST(asset, asset, ...)
//   LIST(asset, ...)
//   LIST(asset, asset, asset, ...)
//
// as one batch request containing three list items.
//
// This example shows both layers explicitly:
// - the outer loop walks the top-level batch of LIST blocks
// - the inner loop walks the ASSET blocks inside one list item
// - the command emits one event per ASSET item, so the behavior is easy to test

import {Host} from "../contracts/Core.sol";
import {CommandBase, CommandContext, Keys} from "../contracts/Endpoints.sol";
import {Cursors, Cur} from "../contracts/Cursors.sol";

using Cursors for Cur;

// Off-chain schema metadata may describe this list as:
//
//   many #asset
//
// means "one LIST block whose payload is a repeated stream of ASSET blocks".
// The request can still batch multiple such LIST blocks at the top level.

abstract contract MyCommand is CommandBase {
    bytes32 private immutable descriptor;
    event AssetSeen(uint indexed listIndex, bytes32 asset);

    constructor() {
        (, descriptor) = command("myCommand", Keys.Empty, many(Keys.Asset), Keys.Empty, 0, false, false);
    }

    // consumeAssetList parses one top-level LIST block in place.
    // `input.list()` consumes the LIST header and returns the byte offset
    // immediately after that list payload. The same cursor then walks the
    // ASSET members inside the list until it reaches that boundary.
    //
    // When this hook returns, `input.i` is positioned exactly at the next
    // top-level block in the request, so the outer loop can keep batching
    // over additional LIST blocks.
    function consumeAssetList(Cur memory input, uint listIndex) internal {
        uint next = input.list();

        while (input.i < next) {
            bytes32 asset = input.unpackAsset();
            emit AssetSeen(listIndex, asset);
        }

        input.ensureAt(next);
    }

    function myCommand(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        Cur memory input = Cursors.open(c.request);
        uint listIndex;

        // INPUT publishes one list item descriptor, but the request is still a
        // top-level batch. Each iteration here consumes one LIST block and
        // emits one event for every ASSET block inside that list.
        while (input.i < input.len) {
            consumeAssetList(input, listIndex);

            unchecked {
                ++listIndex;
            }
        }

        input.complete();
        return "";
    }
}

// Concrete host so the example can be deployed and the command can be called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero) {}
}
