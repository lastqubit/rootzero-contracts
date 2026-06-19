// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Layout} from "./Layout.sol";
import {ensureAddr, isFamily, toLocalBase, toUnspecifiedBase} from "./Utils.sol";

/// @title Accounts
/// @notice Encoding and decoding helpers for 256-bit account identifiers.
///
/// Account IDs embed a 4-byte type tag in bits [255:224]:
///   - `Admin`    — chain-local EVM address in bits [191:32]
///   - `Guardian` — chain-local EVM address in bits [191:32]
///   - `User`     — chain-agnostic EVM address in bits [191:32]
///
/// If the first byte is zero, the account is an opaque
/// `0x00 || bytes31(hash)` ID. The full account identity must be supplied by
/// lookup or witness data when native account metadata is needed.
///
/// The helpers in this library validate and deconstruct structured account IDs.
library Accounts {
    /// @dev Thrown when an account ID does not belong to the EVM family.
    error InvalidAccount();

    /// @dev 24-bit family tag shared by all EVM-backed account types.
    uint24 constant Family = (uint24(Layout.Evm) << 8) | uint24(Layout.Account);
    /// @dev Full 4-byte type prefix for admin accounts (chain-local EVM address).
    uint32 constant Admin = (uint32(Layout.Evm) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.Admin);
    /// @dev Full 4-byte type prefix for guardian accounts (chain-local EVM address).
    uint32 constant Guardian = (uint32(Layout.Evm) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.Guardian);
    /// @dev Full 4-byte type prefix for user accounts (chain-agnostic EVM address).
    uint32 constant User = (uint32(Layout.Evm) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.User);

    /// @notice Extract the 4-byte type prefix from an account ID.
    /// @param account Account identifier.
    /// @return Four-byte prefix occupying bits [255:224].
    function prefix(bytes32 account) internal pure returns (uint32) {
        return uint32(uint(account) >> 224);
    }

    /// @notice Return true if `account` uses the Account category tag in the type field.
    function isAccount(bytes32 account) internal pure returns (bool) {
        return uint8(uint(account) >> 232) == Layout.Account;
    }

    /// @notice Return true if `account` is an admin account.
    function isAdmin(bytes32 account) internal pure returns (bool) {
        return prefix(account) == Admin;
    }

    /// @notice Return true if `account` is a guardian account.
    function isGuardian(bytes32 account) internal pure returns (bool) {
        return prefix(account) == Guardian;
    }

    /// @notice Return true if `account` is a user account.
    function isUser(bytes32 account) internal pure returns (bool) {
        return prefix(account) == User;
    }

    /// @notice Assert that `input` is an account and return it unchanged.
    /// @param input Account identifier to validate.
    /// @return account The same `input` if it is an account.
    function ensure(bytes32 input) internal pure returns (bytes32 account) {
        if (!isAccount(input)) revert InvalidAccount();
        return input;
    }

    /// @notice Assert that `input` is an admin account and return it unchanged.
    /// @param input Account identifier to validate.
    /// @return account The same `input` if it is an admin account.
    function admin(bytes32 input) internal pure returns (bytes32 account) {
        if (!isAdmin(input)) revert InvalidAccount();
        return input;
    }

    /// @notice Assert that `input` is a guardian account and return it unchanged.
    /// @param input Account identifier to validate.
    /// @return account The same `input` if it is a guardian account.
    function guardian(bytes32 input) internal pure returns (bytes32 account) {
        if (!isGuardian(input)) revert InvalidAccount();
        return input;
    }

    /// @notice Assert that `input` is a user account and return it unchanged.
    /// @param input Account identifier to validate.
    /// @return account The same `input` if it is a user account.
    function user(bytes32 input) internal pure returns (bytes32 account) {
        if (!isUser(input)) revert InvalidAccount();
        return input;
    }

    /// @notice Encode an EVM address as a chain-local admin account ID.
    /// @param account EVM address to embed.
    /// @return Admin account ID bound to the current chain.
    function toAdmin(address account) internal view returns (bytes32) {
        return bytes32(toLocalBase(Admin) | (uint(uint160(account)) << 32));
    }

    /// @notice Encode an EVM address as a chain-local guardian account ID.
    /// @param account EVM address to embed.
    /// @return Guardian account ID bound to the current chain.
    function toGuardian(address account) internal view returns (bytes32) {
        return bytes32(toLocalBase(Guardian) | (uint(uint160(account)) << 32));
    }

    /// @notice Encode an EVM address as a chain-agnostic user account ID.
    /// @param account EVM address to embed.
    /// @return User account ID without a chain binding.
    function toUser(address account) internal pure returns (bytes32) {
        return bytes32(toUnspecifiedBase(User) | (uint(uint160(account)) << 32));
    }

    /// @notice Assert that `account` belongs to the EVM account family and return it unchanged.
    /// @param account Account ID to validate.
    /// @return The same `account` value if valid.
    function ensureEvm(bytes32 account) internal pure returns (bytes32) {
        if (!isFamily(uint(account), Family)) {
            revert InvalidAccount();
        }
        return account;
    }

    /// @notice Assert that `account` is not an admin account and return it unchanged.
    /// @param account Account ID to validate.
    /// @return The same `account` value if valid.
    function ensureNotAdmin(bytes32 account) internal pure returns (bytes32) {
        if (isAdmin(account)) revert InvalidAccount();
        return account;
    }

    /// @notice Extract the address embedded in an EVM-family account ID.
    /// Reverts if `account` is not an EVM-family account.
    /// @param account EVM-family account ID.
    /// @return Embedded address (bits [191:32] of the ID).
    function addr(bytes32 account) internal pure returns (address) {
        return ensureAddr(address(uint160(uint(ensureEvm(account)) >> 32)));
    }
}
