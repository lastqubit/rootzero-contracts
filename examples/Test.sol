// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";
import {SwapExactCustodyToBalance, AddLiquidityFromCustodiesToBalances} from "../contracts/Commands.sol";
import {Data, DataRef, DataPairRef, AssetAmount, HostAmount, Writers, Writer} from "../contracts/Blocks.sol";
import {ensureAssetRef} from "../contracts/Utils.sol";

using Data for DataRef;
using Writers for Writer;

contract ExampleHost is Host, SwapExactCustodyToBalance(""), AddLiquidityFromCustodiesToBalances("", 10_000) {
    constructor(address rush) Host(rush, 1, "example") {}

    function swapExactCustodyToBalance(
        bytes32,
        HostAmount memory custody,
        DataRef memory rawRoute
    ) internal override returns (AssetAmount memory out) {
        (bytes32 assetOut, , uint minOut) = rawRoute.innerMinimum();
        uint amountOut = 0;
        return AssetAmount(assetOut, 0, amountOut);
    }

    function addLiquidityFromCustodiesToBalances(
        bytes32 account,
        DataPairRef memory rawCustodies,
        DataRef memory rawRoute,
        Writer memory out
    ) internal override {
        rawCustodies.a.toCustodyValue();
    }
}
