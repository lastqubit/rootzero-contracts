// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";
using Cursors for Cur;

string constant NAME = "transfer";
string constant INPUT = string.concat(Schemas.Amount, "&", Schemas.Recipient);

abstract contract Transfer is CommandBase {
    uint internal immutable transferId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, INPUT, transferId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to transfer funds from `from` to `to`.
    /// Called once per bundled AMOUNT/RECIPIENT pair in the request.
    function transfer(bytes32 from, Cur memory input) internal virtual;

    /// @dev Override to customize request parsing or batching for transfers.
    /// The default implementation iterates bundled AMOUNT/RECIPIENT pairs and calls
    /// `transfer(from, input)` for each one.
    function transfer(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        (Cur memory input, ) = cursor(request, 1);

        while (input.i < input.bound) {
            transfer(from, input);
        }

        input.complete();
        return "";
    }

    function transfer(
        CommandContext calldata c
    ) external payable onlyCommand(transferId, c.target) returns (bytes memory) {
        return transfer(c.account, c.request);
    }
}






