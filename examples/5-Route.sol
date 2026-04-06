// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 5: Route Blocks
//
// Route blocks let a command accept arbitrary command-specific parameters
// alongside standard protocol blocks, without breaking the rootzero wire format.
//
// A route block wraps command-specific parameters without breaking the rootzero
// wire format. It can also be bundled with standard protocol blocks.
//
// This example expects a bundle containing a ROUTE block carrying a `host` ID
// and an AMOUNT block. The command reads both, forwards the asset to the target
// host, and returns a CUSTODY block confirming the held asset.

import { CommandBase, CommandContext, Channels } from "../contracts/Commands.sol";
import { Cursors, Cursor, Schemas } from "../contracts/Cursors.sol";

using Cursors for Cursor;

string constant NAME = "myCommand";

// ROUTE describes the route payload schema (a single uint - the target host ID).
string constant ROUTE = "route(uint host)";

// INPUT is the full input schema published with the Command event.
// The "&" separator means: a ROUTE block bundled together with an AMOUNT block.
string constant INPUT = string.concat(ROUTE, "&", Schemas.Amount);

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        // CUSTODIES = this command returns CUSTODY blocks (assets held by another host).
        emit Command(host, NAME, INPUT, myCommandId, Channels.Setup, Channels.Custodies);
    }

    // sendToHost is the virtual hook implementers override to move the asset.
    function sendToHost(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        // Open the bundled request as a cursor over its member stream.
        Cursor memory input = Cursors.openBlock(c.request, 0);

        // The first bundled member is the ROUTE block.
        uint host = input.unpackRouteUint();

        // The second bundled member is the AMOUNT block.
        (bytes32 asset, bytes32 meta, uint amount) = input.unpackAmount();

        // Delegate to the implementer to move the asset to the target host.
        sendToHost(host, asset, meta, amount);

        // Return a CUSTODY block recording that this asset is now held by `host`.
        return Cursors.toCustodyBlock(host, asset, meta, amount);
    }
}




