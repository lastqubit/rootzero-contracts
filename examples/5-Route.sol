// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 5: Route Blocks
//
// Route blocks let a command accept arbitrary command-specific parameters
// alongside standard protocol blocks, without breaking the rootzero wire format.
//
// In the current cursor model, bundled inputs are handled explicitly:
// create a cursor for the request, call `bundle()`, then consume the bundle
// members from the returned cursor.
//
// This example expects a bundle containing a ROUTE block carrying a `host` ID
// and an AMOUNT block. The command reads both, forwards the asset to that host,
// and returns a CUSTODY block confirming the held asset.

import {CommandBase, CommandContext, State} from "../contracts/Commands.sol";
import {Cursors, Cur, Schemas, Keys} from "../contracts/Cursors.sol";

using Cursors for Cur;

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
        emit Command(host, NAME, INPUT, myCommandId, State.Empty, State.Custodies, false);
    }

    // sendToHost is the virtual hook implementers override to move the asset.
    function sendToHost(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function myCommand(CommandContext calldata c) external onlyTrusted returns (bytes memory) {
        // Create a cursor for the request, then unwrap the bundle into a
        // second cursor over its member stream.
        Cur memory input = cursor(c.request);
        input.bundle();

        // The first bundled member is the ROUTE block.
        uint host = input.unpackUint(Keys.Route);

        // The second bundled member is the AMOUNT block.
        (bytes32 asset, bytes32 meta, uint amount) = input.unpackAmount();

        // Delegate to the implementer to move the asset to the routed host.
        sendToHost(host, asset, meta, amount);

        // Return a CUSTODY block recording that this asset is now held by `host`.
        return Cursors.toHostAssetAmountBlock(host, asset, meta, amount);
    }
}
