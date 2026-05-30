// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 5: Data Blocks
//
// Data blocks let a command accept arbitrary command-specific parameters
// alongside standard protocol blocks, without breaking the rootzero wire format.
//
// This example uses the data shorthand: a schema that starts with fixed fields
// describes one DATA block. The block carries a fixed `host` ID followed by an
// AMOUNT child block in its tail.

import {CommandBase, CommandContext} from "../contracts/Endpoints.sol";
import {Cursors, Cur, Schemas, Keys} from "../contracts/Cursors.sol";

using Cursors for Cur;

string constant NAME = "myCommand";

// INPUT is the full input schema published with the Command event.
string constant INPUT = string.concat("uint host, ", Schemas.Amount);

function unpackInput(Cur memory input) pure returns (uint targetHost, bytes32 asset, bytes32 meta, uint amount) {
    (uint abs, uint next) = input.expect(input.i, 0, Keys.Data, 32, 0);
    targetHost = uint(bytes32(msg.data[abs:abs + 32]));
    (abs, ) = input.expect(input.i + 8 + 32, next, Keys.Amount, 96, 96);
    asset = bytes32(msg.data[abs:abs + 32]);
    meta = bytes32(msg.data[abs + 32:abs + 64]);
    amount = uint(bytes32(msg.data[abs + 64:abs + 96]));

    input.i = next;
}

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        // CUSTODIES = this command returns CUSTODY blocks.
        emit Command(host, myCommandId, NAME, "1:0:1", INPUT, Keys.Empty, Keys.Custody, false, false);
    }

    // sendToHost is the virtual hook implementers override to move the asset.
    function sendToHost(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function myCommand(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        Cur memory input = Cursors.open(c.request);

        (uint targetHost, bytes32 asset, bytes32 meta, uint amount) = unpackInput(input);

        input.complete();

        // Delegate to the implementer to move the asset to the selected host.
        sendToHost(targetHost, asset, meta, amount);

        // Return a CUSTODY block recording that this asset is now held by `targetHost`.
        return Cursors.toCustodyBlock(targetHost, asset, meta, amount);
    }
}
