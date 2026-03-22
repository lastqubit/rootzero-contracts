// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, CUSTODIES, SETUP} from "./Base.sol";
import {HostAmount, AMOUNT, AMOUNT_KEY, NODE} from "../blocks/Schema.sol";
import {Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";
using Blocks for BlockRef;
using Writers for Writer;

string constant NAME = "provision";
string constant REQUEST = string.concat(AMOUNT, ">", NODE);

abstract contract Provision is CommandBase {
    uint internal immutable provisionId = commandId(NAME);
    uint internal immutable prvOutScale;

    constructor(uint scaledRatio) {
        prvOutScale = scaledRatio;
        emit Command(host, NAME, REQUEST, provisionId, SETUP, CUSTODIES);
    }

    function provision(
        bytes32 account,
        uint host,
        bytes32 asset,
        bytes32 meta,
        uint amount,
        Writer memory out
    ) internal virtual;

    function provision(
        CommandContext calldata c
    ) external payable onlyCommand(provisionId, c.target) returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledCustodiesFrom(c.request, q, AMOUNT_KEY, prvOutScale);

        while (q < end) {
            BlockRef memory ref = Blocks.from(c.request, q);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(c.request);
            uint h = ref.innerNode(c.request);
            provision(c.account, h, asset, meta, amount, writer);
            q = ref.end;
        }

        return writer.finish();
    }
}
