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
///   - `Erc721` — ERC-721 collection; collection address in bits [191:32]
///   - `Erc1155` — ERC-1155 collection; collection address in bits [191:32]
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
    uint32 constant Erc721 = (uint32(Layout.Evm64) << 16) | (uint32(Layout.Asset) << 8) | uint32(Layout.Erc721);
    /// @dev Full 4-byte type prefix for ERC-1155 assets.
    uint32 constant Erc1155 = (uint32(Layout.Evm64) << 16) | (uint32(Layout.Asset) << 8) | uint32(Layout.Erc1155);

    /// @notice Return true if `asset` uses the 32-byte asset layout with no metadata identity (top byte is `0x20`).
    function is32(bytes32 asset) internal pure returns (bool) {
        return bytes1(asset) == 0x20;
    }

    /// @notice Return true if `asset` uses the 64-byte asset layout with metadata-backed identity (top byte is `0x40`).
    function is64(bytes32 asset) internal pure returns (bool) {
        return bytes1(asset) == 0x40;
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

    /// @notice Create a chain-local ERC-721 asset ID for `collection`.
    /// @param collection ERC-721 collection contract address.
    /// @return Asset ID with `collection` embedded in bits [191:32].
    function toErc721(address collection) internal view returns (bytes32) {
        return bytes32(toLocalBase(Erc721) | (uint(uint160(collection)) << 32));
    }

    /// @notice Create a chain-local ERC-1155 asset ID for `collection`.
    /// @param collection ERC-1155 collection contract address.
    /// @return Asset ID with `collection` embedded in bits [191:32].
    function toErc1155(address collection) internal view returns (bytes32) {
        return bytes32(toLocalBase(Erc1155) | (uint(uint160(collection)) << 32));
    }

    /// @notice Derive a storage key for an (asset, meta) pair.
    /// For 32-byte EVM assets (no meta), the key is the asset ID itself.
    /// For assets with metadata (e.g. ERC-721 or ERC-1155 token IDs), the key is
    /// `keccak256(asset ++ meta)`.
    /// Reverts only if `asset` is zero.
    /// For 32-byte assets, `meta` is ignored and does not affect the derived key.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot (e.g. token ID context).
    /// @return Storage key for the (asset, meta) combination.
    function key(bytes32 asset, bytes32 meta) internal pure returns (bytes32) {
        if (asset == 0) revert InvalidAsset();
        return bytes1(asset) == 0x20 ? asset : keccak256(bytes.concat(asset, meta));
    }

    /// @notice Return true when two local ERC-20 assets are already in canonical token-address order.
    /// Useful for pair-style integrations that require a stable token ordering
    /// regardless of the caller's input order.
    /// Reverts if either asset is not a local ERC-20 asset.
    /// @param a First ERC-20 asset identifier.
    /// @param b Second ERC-20 asset identifier.
    /// @return ordered Whether `a`'s token address is lower than `b`'s token address.
    function isSortedErc20(bytes32 a, bytes32 b) internal view returns (bool ordered) {
        return erc20Addr(a) < erc20Addr(b);
    }

    /// @notice Extract the token addresses for two local ERC-20 assets and report whether they are already ordered.
    /// The returned addresses preserve the original input order.
    /// Reverts if either asset is not a local ERC-20 asset.
    /// @param a First ERC-20 asset identifier.
    /// @param b Second ERC-20 asset identifier.
    /// @return addrA Token address extracted from `a`.
    /// @return addrB Token address extracted from `b`.
    /// @return ordered Whether `addrA` is lower than `addrB`.
    function erc20Addrs(bytes32 a, bytes32 b) internal view returns (address addrA, address addrB, bool ordered) {
        addrA = erc20Addr(a);
        addrB = erc20Addr(b);
        ordered = addrA < addrB;
    }

    /// @notice Extract the ERC-20 contract address from an asset ID.
    /// Reverts if `asset` is not a local ERC-20 asset.
    /// @param asset ERC-20 asset identifier.
    /// @return Token contract address embedded in bits [191:32].
    function erc20Addr(bytes32 asset) internal view returns (address) {
        if (!matchesBase(asset, toLocalBase(Erc20))) revert InvalidAsset();
        return address(uint160(uint(asset) >> 32));
    }

    /// @notice Assert that `asset` is a local ERC-20 for `token` and return it unchanged.
    /// Reverts if `asset` is not a local ERC-20 asset or if its token address differs.
    /// @param asset ERC-20 asset identifier.
    /// @param token Expected token contract address.
    /// @return The same `asset` value if valid.
    function matchErc20(bytes32 asset, address token) internal view returns (bytes32) {
        if (erc20Addr(asset) != token) revert InvalidAsset();
        return asset;
    }

    /// @notice Extract the ERC-721 collection address from an asset ID.
    /// Reverts if `asset` is not a local ERC-721 asset.
    /// @param asset ERC-721 asset identifier.
    /// @return Collection contract address embedded in bits [191:32].
    function erc721Collection(bytes32 asset) internal view returns (address) {
        if (!matchesBase(asset, toLocalBase(Erc721))) revert InvalidAsset();
        return address(uint160(uint(asset) >> 32));
    }

    /// @notice Assert that `asset` is a local ERC-721 for `collection` and return it unchanged.
    /// Reverts if `asset` is not a local ERC-721 asset or if its collection address differs.
    /// @param asset ERC-721 asset identifier.
    /// @param collection Expected ERC-721 collection address.
    /// @return The same `asset` value if valid.
    function matchErc721(bytes32 asset, address collection) internal view returns (bytes32) {
        if (erc721Collection(asset) != collection) revert InvalidAsset();
        return asset;
    }

    /// @notice Extract the ERC-1155 collection address from an asset ID.
    /// Reverts if `asset` is not a local ERC-1155 asset.
    /// @param asset ERC-1155 asset identifier.
    /// @return Collection contract address embedded in bits [191:32].
    function erc1155Collection(bytes32 asset) internal view returns (address) {
        if (!matchesBase(asset, toLocalBase(Erc1155))) revert InvalidAsset();
        return address(uint160(uint(asset) >> 32));
    }

    /// @notice Assert that `asset` is a local ERC-1155 for `collection` and return it unchanged.
    /// Reverts if `asset` is not a local ERC-1155 asset or if its collection address differs.
    /// @param asset ERC-1155 asset identifier.
    /// @param collection Expected ERC-1155 collection address.
    /// @return The same `asset` value if valid.
    function matchErc1155(bytes32 asset, address collection) internal view returns (bytes32) {
        if (erc1155Collection(asset) != collection) revert InvalidAsset();
        return asset;
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
