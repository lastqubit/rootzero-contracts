// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 5: Data Blocks
//
// Data blocks let a command accept arbitrary command-specific parameters
// alongside standard protocol blocks, without breaking the rootzero wire format.
//
// This example expects one DATA block carrying a fixed `host` ID followed by
// an AMOUNT child block in the DATA block tail. The command reads both, forwards
// the asset to that host, and returns a CUSTODY block confirming the held asset.

import {CommandBase, CommandContext} from "../contracts/Commands.sol";
import {Cursors, Cur, Schemas, Keys} from "../contracts/Cursors.sol";

using Cursors for Cur;

string constant NAME = "myCommand";

// INPUT is the full input schema published with the Command event.
string constant INPUT = string.concat("#data { uint host, ", Schemas.Amount, " }");

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        // CUSTODIES = this command returns CUSTODY blocks.
        emit Command(host, myCommandId, NAME, "1:0:1", INPUT, Keys.Empty, Keys.Custody, false);
    }

    // sendToHost is the virtual hook implementers override to move the asset.
    function sendToHost(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function myCommand(CommandContext calldata c) external onlyTrusted returns (bytes memory) {
        // Create a cursor for the request, then consume the DATA block while
        // allowing a child block tail after the fixed host field.
        Cur memory input = cursor(c.request);
        uint abs = input.consume(Keys.Data, 32, 0);
        uint targetHost = uint(bytes32(msg.data[abs:abs + 32]));
        Cur memory tail = input.slice(abs + 32 - input.offset, input.i);

        // The DATA tail contains the AMOUNT child block.
        (bytes32 asset, bytes32 meta, uint amount) = tail.unpackAmount();
        tail.end();
        input.end();

        // Delegate to the implementer to move the asset to the selected host.
        sendToHost(targetHost, asset, meta, amount);

        // Return a CUSTODY block recording that this asset is now held by `targetHost`.
        return Cursors.toCustodyBlock(targetHost, asset, meta, amount);
    }
}
