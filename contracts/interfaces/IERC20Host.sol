// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IERC20Host {
    function pullToken(bytes32 asset, uint amount) external;
}
