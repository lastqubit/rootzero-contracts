// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 6: List Blocks
//
// `asset(...)[]` means: one LIST block whose payload is a stream of ASSET blocks.
// That does not change the top-level request model: requests are still batches of
// top-level blocks. So a command with INPUT = `asset(...)[]` accepts:
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
import {CommandBase, CommandContext, State} from "../contracts/Commands.sol";
import {Cursors, Cur, Schemas} from "../contracts/Cursors.sol";

using Cursors for Cur;

string constant NAME = "myCommand";

// Lists are declared by taking one item shape and adding `[]`.
// Here the item shape is `asset(bytes32 asset, bytes32 meta)`, so:
//
//   asset(bytes32 asset, bytes32 meta)[]
//
// means "one LIST block whose payload is a repeated stream of ASSET blocks".
// The request can still batch multiple such LIST blocks at the top level.
string constant INPUT = string.concat(Schemas.Asset, "[]");

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);
    event AssetSeen(uint indexed listIndex, bytes32 asset, bytes32 meta);

    constructor() {
        emit Command(host, NAME, INPUT, myCommandId, State.Empty, State.Empty, false);
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
            (bytes32 asset, bytes32 meta) = input.unpackAsset();
            emit AssetSeen(listIndex, asset, meta);
        }

        input.ensure(next);
    }

    function myCommand(CommandContext calldata c) external onlyTrusted returns (bytes memory) {
        Cur memory request = cursor(c.request);
        uint listIndex;

        // INPUT publishes one list item shape, but the request is still a
        // top-level batch. Each iteration here consumes one LIST block and
        // emits one event for every ASSET block inside that list.
        while (request.i < request.len) {
            consumeAssetList(request, listIndex);

            unchecked {
                ++listIndex;
            }
        }

        request.end();
        return "";
    }
}

// Concrete host so the example can be deployed and the command can be called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero, 1, "example") {}
}
