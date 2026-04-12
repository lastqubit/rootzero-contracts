// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Layout} from "./Layout.sol";
import {matchesBase, toLocalBase} from "./Utils.sol";

/// @title Assets
/// @notice Encoding and decoding helpers for 256-bit asset identifiers.
///
/// Asset IDs embed a 4-byte type tag in bits [255:224]:
///   - `Value`  — native chain value (ETH); no address payload
///   - `Erc20`  — ERC-20 token; contract address in bits [191:32]
///   - `Erc721` — ERC-721 collection; issuer address in bits [191:32]
///
/// All asset IDs are chain-local (include `block.chainid` in bits [223:192]).
library Assets {
    /// @dev Thrown when an asset ID does not match the expected type or chain.
    error InvalidAsset();

    /// @dev Full 4-byte type prefix for the native value asset.
    uint32 constant Value = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Asset) << 8) | uint32(Layout.Value);
    /// @dev Full 4-byte type prefix for ERC-20 assets.
    uint32 constant Erc20 = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Asset) << 8) | uint32(Layout.Erc20);
    /// @dev Full 4-byte type prefix for ERC-721 assets.
    uint32 constant Erc721 = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Asset) << 8) | uint32(Layout.Erc721);

    /// @notice Return true if `asset` uses the 32-byte EVM layout (top byte is `0x20`).
    function is32(bytes32 asset) internal pure returns (bool) {
        return bytes1(asset) == 0x20;
    }

    /// @notice Create a chain-local native value asset ID.
    /// @return Asset ID for the native token on the current chain.
    function toValue() internal view returns (bytes32) {
        return bytes32(toLocalBase(Value));
    }

    /// @notice Create a chain-local ERC-20 asset ID for `addr`.
    /// @param addr ERC-20 token contract address.
    /// @return Asset ID with `addr` embedded in bits [191:32].
    function toErc20(address addr) internal view returns (bytes32) {
        return bytes32(toLocalBase(Erc20) | (uint(uint160(addr)) << 32));
    }

    /// @notice Create a chain-local ERC-721 asset ID for `issuer`.
    /// @param issuer ERC-721 collection contract address.
    /// @return Asset ID with `issuer` embedded in bits [191:32].
    function toErc721(address issuer) internal view returns (bytes32) {
        return bytes32(toLocalBase(Erc721) | (uint(uint160(issuer)) << 32));
    }

    /// @notice Derive a storage key for an (asset, meta) pair.
    /// For 32-byte EVM assets (no meta), the key is the asset ID itself.
    /// For assets with metadata (e.g. ERC-721 token IDs), the key is
    /// `keccak256(asset ++ meta)`.
    /// Reverts if `asset` is zero, or if it is a 32-byte asset but `meta` is non-zero.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot (e.g. token ID context).
    /// @return Storage key for the (asset, meta) combination.
    function key(bytes32 asset, bytes32 meta) internal pure returns (bytes32) {
        if (asset == 0 || (bytes1(asset) == 0x20 && meta != 0)) revert InvalidAsset();
        return bytes1(asset) == 0x20 ? asset : keccak256(bytes.concat(asset, meta));
    }

    /// @notice Extract the ERC-20 contract address from an asset ID.
    /// Reverts if `asset` is not a local ERC-20 asset.
    /// @param asset ERC-20 asset identifier.
    /// @return Token contract address embedded in bits [191:32].
    function erc20Addr(bytes32 asset) internal view returns (address) {
        if (!matchesBase(asset, toLocalBase(Erc20))) revert InvalidAsset();
        return address(uint160(uint(asset) >> 32));
    }

    /// @notice Extract the ERC-721 issuer address from an asset ID.
    /// Reverts if `asset` is not a local ERC-721 asset.
    /// @param asset ERC-721 asset identifier.
    /// @return Issuer contract address embedded in bits [191:32].
    function erc721Issuer(bytes32 asset) internal view returns (address) {
        if (!matchesBase(asset, toLocalBase(Erc721))) revert InvalidAsset();
        return address(uint160(uint(asset) >> 32));
    }
}

/// @title Amounts
/// @notice Validation helpers for token amounts.
library Amounts {
    /// @dev Thrown when a required non-zero amount is zero.
    error ZeroAmount();
    /// @dev Thrown when an amount falls outside the allowed `[min, max]` range.
    error BadAmount(uint amount);

    /// @notice Assert that `amount` is non-zero and return it unchanged.
    /// @param amount Amount to validate.
    /// @return The same `amount` value if valid.
    function ensure(uint amount) internal pure returns (uint) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        return amount;
    }

    /// @notice Assert that `amount` is within `[min, max]` and return it unchanged.
    /// @param amount Amount to validate.
    /// @param min Inclusive lower bound.
    /// @param max Inclusive upper bound.
    /// @return The same `amount` value if valid.
    function ensure(uint amount, uint min, uint max) internal pure returns (uint) {
        if (amount < min || amount > max) {
            revert BadAmount(amount);
        }
        return amount;
    }

    /// @notice Assert non-zero amount and derive the storage key for the (asset, meta) pair.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to validate (must be non-zero).
    /// @return key_ Storage key from `Assets.key(asset, meta)`.
    function ensureKey(bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes32 key_) {
        ensure(amount);
        return Assets.key(asset, meta);
    }

    /// @notice Clamp `available` to `[min, max]`.
    /// Uses all of `available` if it does not exceed `max`; reverts if the result
    /// would fall below `min`.
    /// @param available Total available balance.
    /// @param min Minimum acceptable resolved amount.
    /// @param max Maximum amount to consume.
    /// @return Clamped amount in `[min, max]`.
    function resolve(uint available, uint min, uint max) internal pure returns (uint) {
        uint amount = available > max ? max : available;
        if (amount < min) {
            revert BadAmount(amount);
        }
        return amount;
    }
}
