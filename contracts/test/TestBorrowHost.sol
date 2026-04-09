// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { BorrowAgainstCustodyToBalance } from "../commands/Borrow.sol";
import { AssetAmount, HostAmount } from "../blocks/Schema.sol";
import { Cur, Cursors, Keys } from "../Cursors.sol";
import { Ids } from "../utils/Ids.sol";

using Cursors for Cur;

contract TestBorrowHost is Host, BorrowAgainstCustodyToBalance {
    event BorrowCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, bytes inputData);

    bytes32 public returnAsset;
    bytes32 public returnMeta;
    uint public returnAmount;

    constructor(address cmdr) Host(address(0), 1, "test") BorrowAgainstCustodyToBalance("") {
        if (cmdr != address(0)) access(Ids.toHost(cmdr), true);
    }

    function setReturn(bytes32 asset, bytes32 meta, uint amount) external {
        returnAsset = asset;
        returnMeta = meta;
        returnAmount = amount;
    }

    function borrowAgainstCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request
    ) internal override returns (AssetAmount memory) {
        if (request.i < request.len) {
            bytes calldata inputData;
            (bytes4 key, uint len) = request.peek(request.i);
            if (key == Keys.Bundle) {
                Cur memory bundle = request.bundle();
                (key, len) = bundle.peek(bundle.i);
                if (key == Keys.Route) {
                    inputData = bundle.unpackRoute();
                } else {
                    uint next = bundle.i + 8 + len;
                    inputData = msg.data[bundle.offset + bundle.i:bundle.offset + next];
                    bundle.i = next;
                }
            } else if (key == Keys.Route) {
                inputData = request.unpackRoute();
            } else {
                uint next = request.i + 8 + len;
                inputData = msg.data[request.offset + request.i:request.offset + next];
                request.i = next;
            }
            emit BorrowCalled(account, custody.asset, custody.meta, custody.amount, inputData);
        } else {
            emit BorrowCalled(account, custody.asset, custody.meta, custody.amount, "");
        }
        return AssetAmount({asset: returnAsset, meta: returnMeta, amount: returnAmount});
    }

    function getBorrowId() external view returns (uint) {
        return borrowAgainstCustodyToBalanceId;
    }

    function getAdminAccount() external view returns (bytes32) {
        return adminAccount;
    }
}




