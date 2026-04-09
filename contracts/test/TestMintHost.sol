// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { MintToBalances } from "../commands/Mint.sol";
import { Cursors, Cur, Writer, Keys } from "../Cursors.sol";
import { Writers } from "../blocks/Writers.sol";
import { Ids } from "../utils/Ids.sol";

using Cursors for Cur;
using Writers for Writer;

contract TestMintHost is Host, MintToBalances {
    event MintCalled(bytes32 account, bytes inputData);

    bytes32 public returnAsset;
    bytes32 public returnMeta;
    uint    public returnAmount;

    constructor(address cmdr)
        Host(address(0), 1, "test")
        MintToBalances("", 10_000)
    {
        if (cmdr != address(0)) access(Ids.toHost(cmdr), true);
    }

    function setReturn(bytes32 asset, bytes32 meta, uint amount) external {
        returnAsset = asset;
        returnMeta  = meta;
        returnAmount = amount;
    }

    function mintToBalances(bytes32 account, Cur memory input, Writer memory out) internal override {
        (bytes4 key, uint len) = input.peek(input.i);
        uint next = input.i + 8 + len;
        bytes calldata inputData = key == Keys.Route
            ? input.unpackRoute()
            : msg.data[input.offset + input.i:input.offset + next];
        input.i = next;
        emit MintCalled(account, inputData);
        if (returnAmount > 0) out.appendBalance(returnAsset, returnMeta, returnAmount);
    }

    function getMintId() external view returns (uint) { return mintToBalancesId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}




