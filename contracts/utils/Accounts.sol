// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Layout} from "./Layout.sol";
import {isFamily, toLocalBase, toUnspecifiedBase} from "./Utils.sol";

/// @title Accounts
/// @notice Encoding and decoding helpers for 256-bit account identifiers.
///
/// Account IDs embed a 4-byte type tag in bits [255:224]:
///   - `Admin`    — chain-local EVM address in bits [191:32]
///   - `Guardian` — chain-local EVM address in bits [191:32]
///   - `User`     — chain-agnostic EVM address in bits [191:32]
library Accounts {
    /// @dev Thrown when an account ID does not belong to the EVM family.
    error InvalidAccount();

    /// @dev 24-bit family tag shared by all EVM-backed account types.
    uint24 constant Family = (uint24(Layout.Evm32) << 8) | uint24(Layout.Account);
    /// @dev Full 4-byte type prefix for admin accounts (chain-local EVM address).
    uint32 constant Admin = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.Admin);
    /// @dev Full 4-byte type prefix for guardian accounts (chain-local EVM address).
    uint32 constant Guardian = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.Guardian);
    /// @dev Full 4-byte type prefix for user accounts (chain-agnostic EVM address).
    uint32 constant User = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.User);
    /// @dev Full 4-byte type prefix for keccak accounts (opaque 28-byte hash).
    uint32 constant Keccak = (uint32(Layout.Opaque32) << 16) | (uint32(Layout.Account) << 8) | uint32(Layout.Keccak);

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

    function isKeccak(bytes32 account) internal pure returns (bool) {
        return prefix(account) == Keccak;
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

    /// @notice Assert that `input` is a keccak account and return it unchanged.
    /// @param input Account identifier to validate.
    /// @return account The same `input` if it is a keccak account.
    function keccak(bytes32 input) internal pure returns (bytes32 account) {
        if (!isKeccak(input)) revert InvalidAccount();
        return input;
    }

    /// @notice Encode an EVM address as a chain-local admin account ID.
    /// @param addr EVM address to embed.
    /// @return Admin account ID bound to the current chain.
    function toAdmin(address addr) internal view returns (bytes32) {
        return bytes32(toLocalBase(Admin) | (uint(uint160(addr)) << 32));
    }

    /// @notice Encode an EVM address as a chain-local guardian account ID.
    /// @param addr EVM address to embed.
    /// @return Guardian account ID bound to the current chain.
    function toGuardian(address addr) internal view returns (bytes32) {
        return bytes32(toLocalBase(Guardian) | (uint(uint160(addr)) << 32));
    }

    /// @notice Encode an EVM address as a chain-agnostic user account ID.
    /// @param addr EVM address to embed.
    /// @return User account ID without a chain binding.
    function toUser(address addr) internal pure returns (bytes32) {
        return bytes32(toUnspecifiedBase(User) | (uint(uint160(addr)) << 32));
    }

    function toKeccak(bytes32 head, bytes32 meta) internal pure returns (bytes32) {
        return bytes32(toUnspecifiedBase(Keccak) | uint224(uint256(keccak256(bytes.concat(head, meta)))));
    }

    function matchesKeccak(bytes32 account, bytes32 head, bytes32 meta) internal pure returns (bool) {
        return account == toKeccak(head, meta);
    }

    /// @notice Assert that `account` uses the Account layout tag and return it unchanged.
    /// Ignores width, chain binding, and subtype details.
    /// @param account Account ID to validate.
    /// @return The same `account` value if valid.
    function ensure(bytes32 account) internal pure returns (bytes32) {
        if (uint8(uint(account) >> 232) != Layout.Account) {
            revert InvalidAccount();
        }
        return account;
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

    /// @notice Extract the EVM address embedded in an EVM-family account ID.
    /// Reverts if `account` is not an EVM-family account.
    /// @param account EVM-family account ID.
    /// @return Embedded EVM address (bits [191:32] of the ID).
    function addrEvm(bytes32 account) internal pure returns (address) {
        return address(uint160(uint(ensureEvm(account)) >> 32));
    }
}
