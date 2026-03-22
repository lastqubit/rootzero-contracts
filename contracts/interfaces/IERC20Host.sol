// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Add function to set allocation of sender... doesn't work?

interface IERC20Host {
    function pullToken(bytes32 asset, uint amount) external;

    function pullTokens(bytes32 asset0, uint amount0, bytes32 asset1, uint amount1) external;
}
