// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Layout} from "./Layout.sol";
import {ensureAddr, matchesBase, toLocalBase} from "./Utils.sol";

/// @title Assets
/// @notice Encoding and decoding helpers for 256-bit asset identifiers.
///
/// Asset IDs embed a 4-byte type tag in bits [255:224]:
///   - `Native` - native chain coin/token; no address payload
///   - `Erc20` - ERC-20 token; contract address in bits [191:32]
///
/// If the first byte is zero, the asset is an opaque
/// `0x00 || bytes31(hash)` ID. The full asset metadata must be supplied by
/// lookup or witness data when native token handling needs it.
///
/// The helpers in this library validate and deconstruct structured asset IDs.
///
/// All asset IDs are chain-local (include `block.chainid` in bits [223:192]).
library Assets {
    /// @dev Thrown when an asset ID does not match the expected type or chain.
    error InvalidAsset();
    /// @dev Thrown when an asset is not authorized for the requested operation.
    error UnauthorizedAsset();

    /// @dev Full 4-byte type prefix for the native chain coin/token asset.
    uint32 constant Native = (uint32(Layout.Evm) << 16) | (uint32(Layout.Asset) << 8) | uint32(Layout.Native);
    /// @dev Full 4-byte type prefix for ERC-20 assets.
    uint32 constant Erc20 = (uint32(Layout.Evm) << 16) | (uint32(Layout.Asset) << 8) | uint32(Layout.Erc20);

    /// @notice Return true if `asset` uses the Asset category tag in the type field.
    function isAsset(bytes32 asset) internal pure returns (bool) {
        return uint8(uint(asset) >> 232) == Layout.Asset;
    }

    /// @notice Return true if `asset` is the local native chain coin/token asset.
    function isNative(bytes32 asset) internal view returns (bool) {
        return asset == toNative();
    }

    /// @notice Return true if `asset` is a local ERC-20 asset.
    function isErc20(bytes32 asset) internal view returns (bool) {
        return matchesBase(asset, toLocalBase(Erc20));
    }

    /// @notice Assert that `input` is the local native chain coin/token asset and return it unchanged.
    /// @param input Asset identifier to validate.
    /// @return asset The same `input` if it is the local native asset.
    function native(bytes32 input) internal view returns (bytes32 asset) {
        if (!isNative(input)) revert InvalidAsset();
        return input;
    }

    /// @notice Assert that `input` is a local ERC-20 asset and return it unchanged.
    /// @param input Asset identifier to validate.
    /// @return asset The same `input` if it is a local ERC-20 asset.
    function erc20(bytes32 input) internal view returns (bytes32 asset) {
        if (!isErc20(input)) revert InvalidAsset();
        return input;
    }

    /// @notice Create a chain-local native coin/token asset ID.
    /// @return Asset ID for the native token on the current chain.
    function toNative() internal view returns (bytes32) {
        return bytes32(toLocalBase(Native));
    }

    /// @notice Create a chain-local ERC-20 asset ID for `addr`.
    /// @param addr ERC-20 token contract address.
    /// @return Asset ID with `addr` embedded in bits [191:32].
    function toErc20(address addr) internal view returns (bytes32) {
        return bytes32(toLocalBase(Erc20) | (uint(uint160(addr)) << 32));
    }

    /// @notice Extract the ERC-20 contract address from an asset ID.
    /// Reverts if `asset` is not a local ERC-20 asset.
    /// @param asset ERC-20 asset identifier.
    /// @return Token contract address embedded in bits [191:32].
    function erc20Addr(bytes32 asset) internal view returns (address) {
        return ensureAddr(address(uint160(uint(erc20(asset)) >> 32)));
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
