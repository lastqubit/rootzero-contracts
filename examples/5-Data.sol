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

import {CommandBase, Specs} from "../contracts/Endpoints.sol";
import {Blocks, Cursors, Cur, Sizes} from "../contracts/Cursors.sol";

using Cursors for Cur;

abstract contract MyCommand is CommandBase {
    string private constant INPUT = "{ uint host, #amount as amount }";
    uint private immutable inputSpec;
    uint private immutable descriptor;

    constructor() {
        uint32 size = uint32(32 + Sizes.Amount);
        inputSpec = schema(1, size, size, size, INPUT, bytes32(0));
        (, descriptor) = command("myCommand", Specs.Empty, inputSpec, Specs.Custody, 0, false, false);
    }

    // sendToHost is the virtual hook implementers override to move the asset.
    function sendToHost(uint host, bytes32 asset, uint amount) internal virtual;

    function unpackInput(Cur memory input) private view returns (uint targetHost, bytes32 asset, uint amount) {
        uint end = input.enter(inputSpec);
        targetHost = input.readUint();
        (asset, amount) = input.unpackAmount();
        input.ensureAt(end);
    }

    function myCommand(
        bytes32,
        bytes calldata,
        bytes calldata request
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Cur memory input = Cursors.openCur(request);

        (uint targetHost, bytes32 asset, uint amount) = unpackInput(input);

        input.complete();

        // Delegate to the implementer to move the asset to the selected host.
        sendToHost(targetHost, asset, amount);

        // Return a CUSTODY block recording that this asset is now held by `targetHost`.
        return (Blocks.custody(targetHost, asset, amount), "");
    }
}
