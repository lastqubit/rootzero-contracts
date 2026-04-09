// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { SwapExactBalanceToBalance } from "../commands/Swap.sol";
import { AssetAmount, Cur, Cursors, Cursors, Keys } from "../Cursors.sol";

using Cursors for Cur;

contract TestSwapHost is Host, SwapExactBalanceToBalance {
    event SwapMapped(bytes32 account, bytes32 asset, bytes32 meta, uint amount, bytes inputData);
    event SwapMinimum(bytes32 asset, bytes32 meta, uint amount);

    constructor(address rootzero)
        Host(rootzero, 1, "test")
        SwapExactBalanceToBalance("route(bytes data)")
    {}

    function swapExactBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request
    ) internal override returns (AssetAmount memory out) {
        if (request.i == request.len) revert Cursors.InvalidBlock();

        Cur memory input = request;
        (bytes4 key, uint len) = request.peek(request.i);
        if (key == Keys.Bundle) input = request.bundle();

        bytes calldata inputData;
        (key, len) = input.peek(input.i);
        if (key == Keys.Route) {
            inputData = input.unpackRoute();
        } else {
            uint next = input.i + 8 + len;
            inputData = msg.data[input.offset + input.i:input.offset + next];
            input.i = next;
        }
        emit SwapMapped(account, balance.asset, balance.meta, balance.amount, inputData);

        if (input.i < input.len) {
            (key, ) = input.peek(input.i);
        }
        if (input.i < input.len && key == Keys.Minimum) {
            (bytes32 minAsset, bytes32 minMeta, uint minAmount) = input.unpackMinimum();
            emit SwapMinimum(minAsset, minMeta, minAmount);
        }

        return AssetAmount({
            asset: balance.asset,
            meta: bytes32(inputData.length),
            amount: balance.amount + inputData.length
        });
    }

    function getSwapExactInAsset32Id() external view returns (uint) {
        return swapExactBalanceToBalanceId;
    }

    function getAdminAccount() external view returns (bytes32) {
        return adminAccount;
    }
}




