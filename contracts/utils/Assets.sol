// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ASSET, ERC20, ERC721, EVM32, VALUE} from "./Layout.sol";
import {matchesBase, toLocalBase} from "./Utils.sol";

uint32 constant VALUE_PREFIX = (uint32(EVM32) << 16) | (uint32(ASSET) << 8) | uint32(VALUE);
uint32 constant ERC20_PREFIX = (uint32(EVM32) << 16) | (uint32(ASSET) << 8) | uint32(ERC20);
uint32 constant ERC721_PREFIX = (uint32(EVM32) << 16) | (uint32(ASSET) << 8) | uint32(ERC721);

error ZeroAmount();
error InvalidAsset();
error BadAmount(uint amount);

function isAsset32(bytes32 asset) pure returns (bool) {
    return bytes1(asset) == 0x20;
}

function toValueAsset() view returns (bytes32) {
    return bytes32(toLocalBase(VALUE_PREFIX));
}

function toErc20Asset(address addr) view returns (bytes32) {
    return bytes32(toLocalBase(ERC20_PREFIX) | (uint(uint160(addr)) << 32));
}

function toErc721Asset(address issuer) view returns (bytes32) {
    return bytes32(toLocalBase(ERC721_PREFIX) | (uint(uint160(issuer)) << 32));
}

function resolveAmount(uint available, uint min, uint max) pure returns (uint) {
    uint amount = available > max ? max : available;
    if (amount < min) {
        revert BadAmount(amount);
    }
    return amount;
}

function ensureAmount(uint amount) pure returns (uint) {
    if (amount == 0) {
        revert ZeroAmount();
    }
    return amount;
}

function ensureAmount(uint amount, uint min, uint max) pure returns (uint) {
    if (amount < min || amount > max) {
        revert BadAmount(amount);
    }
    return amount;
}

function ensureAssetRef(bytes32 asset, bytes32 meta) pure returns (bytes32) {
    if (asset == 0 || (bytes1(asset) == 0x20 && meta != 0)) revert InvalidAsset();
    return bytes1(asset) == 0x20 ? asset : keccak256(bytes.concat(asset, meta));
}

function ensureBalanceRef(bytes32 asset, bytes32 meta, uint amount) pure returns (bytes32 ref) {
    ensureAmount(amount);
    return ensureAssetRef(asset, meta);
}

function localErc20Addr(bytes32 asset) view returns (address) {
    if (!matchesBase(asset, toLocalBase(ERC20_PREFIX))) revert InvalidAsset();
    return address(uint160(uint(asset) >> 32));
}

function localErc721Issuer(bytes32 asset) view returns (address) {
    if (!matchesBase(asset, toLocalBase(ERC721_PREFIX))) revert InvalidAsset();
    return address(uint160(uint(asset) >> 32));
}
