// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IRequestAllowAsset {
    function requestAllowAsset(bytes32 asset, bytes32 meta) external returns (bool);
}
