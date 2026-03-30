// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { SwapExactBalanceToBalance } from "../commands/Swap.sol";
import { AssetAmount, Block, Blocks } from "../Blocks.sol";

using Blocks for Block;

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
        Block memory rawInput
    ) internal override returns (AssetAmount memory out) {
        bytes calldata inputData = msg.data[rawInput.i:rawInput.bound];
        emit SwapMapped(account, balance.asset, balance.meta, balance.amount, inputData);
        if (rawInput.bound < rawInput.end) {
            (bytes32 minAsset, bytes32 minMeta, uint minAmount) = rawInput.innerMinimum();
            emit SwapMinimum(minAsset, minMeta, minAmount);
        }
        return AssetAmount({
            asset: balance.asset,
            meta: bytes32(rawInput.bound - rawInput.i),
            amount: balance.amount + (rawInput.bound - rawInput.i)
        });
    }

    function getSwapExactInAsset32Id() external view returns (uint) {
        return swapExactBalanceToBalanceId;
    }

    function getAdminAccount() external view returns (bytes32) {
        return adminAccount;
    }
}
