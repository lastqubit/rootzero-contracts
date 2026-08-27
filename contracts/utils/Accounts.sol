// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Layout} from "./Layout.sol";
import {InvalidAccount} from "./Errors.sol";
import {Ids} from "./Ids.sol";
import {ensureAddr, isFamily, toLocalBase, toUnspecifiedBase} from "./Utils.sol";

/// @title Accounts
/// @notice Encoding and decoding helpers for 256-bit account identifiers.
///
/// Account IDs embed a 4-byte type tag in bits [255:224]:
///   - `Admin`    — chain-local EVM address in bits [191:32]
///   - `User`     — chain-agnostic EVM address in bits [191:32]
///
/// If the first byte is zero, the account is an opaque
/// `0x00 || bytes31(hash)` ID. The full account identity must be supplied by
/// lookup or witness data when native account metadata is needed.
///
/// The helpers in this library validate and deconstruct structured account IDs.
library Accounts {
    /// @dev 24-bit family tag shared by all EVM-backed account types.
    uint24 constant Family = (uint24(Layout.Evm) << 8) | uint24(Layout.Account);
    /// @dev Full 4-byte type prefix for admin accounts (chain-local EVM address).
    uint32 constant Admin = (uint32(Layout.Evm) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.Admin);
    /// @dev Full 4-byte type prefix for user accounts (chain-agnostic EVM address).
    uint32 constant User = (uint32(Layout.Evm) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.User);

    /// @notice Extract the 4-byte type prefix from an account ID.
    /// @param account Account identifier.
    /// @return Four-byte prefix occupying bits [255:224].
    function prefix(bytes32 account) internal pure returns (uint32) {
        return uint32(uint(account) >> 224);
    }

    /// @notice Return true if `account` belongs to the EVM account family.
    function isEvm(bytes32 account) internal pure returns (bool) {
        return isFamily(uint(account), Family);
    }

    /// @notice Return true if `account` is opaque.
    function isOpaque(bytes32 account) internal pure returns (bool) {
        return Ids.isOpaque(account);
    }

    /// @notice Return true if `account` is an admin account.
    function isAdmin(bytes32 account) internal pure returns (bool) {
        return prefix(account) == Admin;
    }

    /// @notice Return true if `account` is a user account.
    function isUser(bytes32 account) internal pure returns (bool) {
        return prefix(account) == User;
    }

    /// @notice Assert that `value` belongs to the EVM account family and return it unchanged.
    /// @param value Account identifier to validate.
    /// @return account The same `value` if it is an EVM account.
    function evm(bytes32 value) internal pure returns (bytes32 account) {
        if (!isEvm(value)) revert InvalidAccount();
        return value;
    }

    /// @notice Assert that `value` is an opaque account and return it unchanged.
    /// @param value Account identifier to validate.
    /// @return account The same `value` if it is opaque.
    function opaque(bytes32 value) internal pure returns (bytes32 account) {
        if (!Ids.isOpaque(value)) revert InvalidAccount();
        return value;
    }

    /// @notice Assert that `value` is an admin account and return it unchanged.
    /// @param value Account identifier to validate.
    /// @return account The same `value` if it is an admin account.
    function admin(bytes32 value) internal pure returns (bytes32 account) {
        if (!isAdmin(value)) revert InvalidAccount();
        return value;
    }

    /// @notice Assert that `value` is a user account and return it unchanged.
    /// @param value Account identifier to validate.
    /// @return account The same `value` if it is a user account.
    function user(bytes32 value) internal pure returns (bytes32 account) {
        if (!isUser(value)) revert InvalidAccount();
        return value;
    }

    /// @notice Encode an EVM address as a chain-local admin account ID.
    /// @param account EVM address to embed.
    /// @return Admin account ID bound to the current chain.
    function toAdmin(address account) internal view returns (bytes32) {
        return bytes32(toLocalBase(Admin) | (uint(uint160(account)) << 32));
    }

    /// @notice Encode an EVM address as a chain-agnostic user account ID.
    /// @param account EVM address to embed.
    /// @return User account ID without a chain binding.
    function toUser(address account) internal pure returns (bytes32) {
        return bytes32(toUnspecifiedBase(User) | (uint(uint160(account)) << 32));
    }

    /// @notice Derive an opaque account ID from a keccak preimage.
    /// @param preimage Preimage whose first byte is `0x01`.
    /// @return account `0x00 || bytes31(keccak256(preimage))`.
    function toKeccak(bytes memory preimage) internal pure returns (bytes32 account) {
        return Ids.toKeccak(preimage);
    }

    /// @notice Assert that `account` matches the opaque keccak ID for `preimage`.
    /// @param account Opaque account ID to validate.
    /// @param preimage Preimage whose first byte is `0x01`.
    /// @return The same `account` value if it matches.
    function matchKeccak(bytes32 account, bytes memory preimage) internal pure returns (bytes32) {
        if (account != Ids.toKeccak(preimage)) revert InvalidAccount();
        return account;
    }

    /// @notice Extract the address embedded in an EVM-family account ID.
    /// Reverts if `account` is not an EVM-family account.
    /// @param account EVM-family account ID.
    /// @return Embedded address (bits [191:32] of the ID).
    function addr(bytes32 account) internal pure returns (address) {
        return ensureAddr(address(uint160(uint(evm(account)) >> 32)));
    }
}
