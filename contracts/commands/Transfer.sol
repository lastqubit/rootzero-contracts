// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, SETUP} from "./Base.sol";
import {AMOUNT, RECIPIENT, AMOUNT_KEY, BlockRef} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
using Blocks for BlockRef;

bytes32 constant NAME = "transfer";
string constant REQUEST = string.concat(AMOUNT, ">", RECIPIENT);

abstract contract Transfer is CommandBase {
    uint internal immutable transferId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, REQUEST, transferId, SETUP, SETUP);
    }

    function transfer(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function transfer(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        uint i = 0;
        while (i < request.length) {
            BlockRef memory ref = Blocks.from(request, i);
            if (ref.key != AMOUNT_KEY) break;
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(request);
            bytes32 to = ref.innerRecipientAt(request, ref.bound);
            transfer(from, to, asset, meta, amount);
            i = ref.end;
        }

        return done(0, i);
    }

    function transfer(
        CommandContext calldata c
    ) external payable onlyCommand(transferId, c.target) returns (bytes memory) {
        return transfer(c.account, c.request);
    }
}
