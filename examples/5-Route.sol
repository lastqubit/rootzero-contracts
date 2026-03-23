// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 5: Route Blocks
//
// Route blocks let a command accept arbitrary command-specific parameters
// alongside standard protocol blocks, without breaking the Rush wire format.
//
// A route block wraps a payload (encoded however the command expects) and can
// optionally contain nested child blocks. The route schema is published in the
// Command event so off-chain tooling knows how to encode it.
//
// This example expects a route block carrying a `host` ID, with an AMOUNT block
// nested inside it. The command reads both, forwards the asset to the target host,
// and returns a CUSTODY block confirming the held asset.

import {CommandBase, CommandContext, CUSTODIES, SETUP} from "../contracts/Commands.sol";
import {AMOUNT} from "../contracts/Schema.sol";
import {Blocks, Data, DataRef} from "../contracts/Blocks.sol";

using Data for DataRef;

string constant NAME = "myCommand";

// ROUTE describes the outer route payload schema (a single uint — the target host ID).
string constant ROUTE = "route(uint host)";

// REQUEST is the full request schema published with the Command event.
// The ">" separator means: a ROUTE block containing an AMOUNT block as a child.
string constant REQUEST = string.concat(ROUTE, ">", AMOUNT);

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        // CUSTODIES = this command returns CUSTODY blocks (assets held by another host).
        emit Command(host, NAME, REQUEST, myCommandId, SETUP, CUSTODIES);
    }

    // sendToHost is the virtual hook implementers override to move the asset.
    function sendToHost(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        // Read the outer route block from the request starting at offset 0.
        (DataRef memory route, ) = Data.routeFrom(c.request, 0);

        // Decode the `host` uint from the route payload.
        uint host = route.unpackRouteUint();

        // Decode the AMOUNT block nested inside the route.
        (bytes32 asset, bytes32 meta, uint amount) = route.innerAmount();

        // Delegate to the implementer to move the asset to the target host.
        sendToHost(host, asset, meta, amount);

        // Return a CUSTODY block recording that this asset is now held by `host`.
        return Blocks.toCustodyBlock(host, asset, meta, amount);
    }
}
