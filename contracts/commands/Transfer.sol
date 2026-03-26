// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { SETUP } from "../utils/Channels.sol";
import { Keys } from "../blocks/Keys.sol";
import { Schemas } from "../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "transfer";
string constant REQUEST = string.concat(Schemas.Amount, ">", Schemas.Recipient);

abstract contract Transfer is CommandBase {
    uint internal immutable transferId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, REQUEST, transferId, SETUP, SETUP);
    }

    /// @dev Override to transfer funds from `from` to `to`.
    /// Called once per AMOUNT>RECIPIENT pair in the request.
    function transfer(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    /// @dev Override to customize request parsing or batching for transfers.
    /// The default implementation iterates AMOUNT>RECIPIENT pairs and calls
    /// `transfer(from, to, asset, meta, amount)` for each one.
    function transfer(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            Block memory ref = Blocks.from(request, q);
            if (ref.key != Keys.Amount) break;
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount();
            bytes32 to = ref.innerRecipientAt(ref.bound);
            transfer(from, to, asset, meta, amount);
            q = ref.cursor;
        }

        return done(0, q);
    }

    function transfer(
        CommandContext calldata c
    ) external payable onlyCommand(transferId, c.target) returns (bytes memory) {
        return transfer(c.account, c.request);
    }
}
