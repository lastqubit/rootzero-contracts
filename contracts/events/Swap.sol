// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Swap(bytes32 indexed account, bytes32 assetIn, uint amountIn, bytes32 assetOut, uint amountOut)";

/// @notice Emitted when an account swaps one asset for another.
abstract contract SwapEvent is EventEmitter {
    /// @param account Account identifier performing the swap.
    /// @param assetIn Input asset identifier.
    /// @param amountIn Input amount spent.
    /// @param assetOut Output asset identifier.
    /// @param amountOut Output amount received.
    event Swap(bytes32 indexed account, bytes32 assetIn, uint amountIn, bytes32 assetOut, uint amountOut);

    constructor() {
        emit EventAbi(ABI);
    }
}
