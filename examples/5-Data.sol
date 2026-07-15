// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 5: Custom Input Blocks
//
// Custom input blocks let a command accept arbitrary command-specific parameters
// alongside standard protocol blocks, without breaking the rootzero wire format.
//
// This example defines a context-local input key for a block that carries a
// fixed `host` ID followed by an
// AMOUNT child block in its tail.

import {CommandBase, CommandContext, Keys} from "../contracts/Endpoints.sol";
import {Cursors, Cur} from "../contracts/Cursors.sol";

using Cursors for Cur;

abstract contract MyCommand is CommandBase {
    string private constant INPUT = "{ uint host, #amount as amount }";

    bytes32 private immutable descriptor;

    constructor() {
        // CUSTODIES = this command returns CUSTODY blocks.
        (, descriptor) = command("myCommand", Keys.Empty, localSchema(INPUT), Keys.Custody, 0, false, false);
    }

    // sendToHost is the virtual hook implementers override to move the asset.
    function sendToHost(uint host, bytes32 asset, uint amount) internal virtual;

    function unpackInput(Cur memory input) private pure returns (uint targetHost, bytes32 asset, uint amount) {
        (uint abs, uint next) = input.expect(input.i, 0, Keys.Local, 32, 0);
        targetHost = uint(bytes32(msg.data[abs:abs + 32]));
        (abs, ) = input.expect(input.i + 8 + 32, next, Keys.Amount, 64, 64);
        asset = bytes32(msg.data[abs:abs + 32]);
        amount = uint(bytes32(msg.data[abs + 32:abs + 64]));

        input.i = next;
    }

    function myCommand(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        Cur memory input = Cursors.open(c.input);

        (uint targetHost, bytes32 asset, uint amount) = unpackInput(input);

        input.complete();

        // Delegate to the implementer to move the asset to the selected host.
        sendToHost(targetHost, asset, amount);

        // Return a CUSTODY block recording that this asset is now held by `targetHost`.
        return Cursors.toCustodyBlock(targetHost, asset, amount);
    }
}
