// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Layout
/// @notice Single-byte and two-byte tag constants that describe the encoding
/// layout of 256-bit IDs used throughout the rootzero protocol.
///
/// IDs are structured as:
///   `[uint16 width][uint16 chainId-prefix][uint32 prefix][... payload ...]`
/// where the top bytes carry nested type tags drawn from the constants below.
library Layout {
    // -------------------------------------------------------------------------
    // Data-width tags (uint16, top 2 bytes of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev 32-byte opaque value; no EVM address embedded.
    uint16 constant Opaque32 = 0x2000;
    /// @dev 32-byte EVM-compatible value; lower 20 bytes hold an address.
    uint16 constant Evm32 = 0x2001;
    /// @dev 64-byte EVM-compatible value (reserved for extended IDs).
    uint16 constant Evm64 = 0x4001;

    // -------------------------------------------------------------------------
    // Category tags (uint8, third byte of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev ID encodes an account.
    uint8 constant Account = 0x01;
    /// @dev ID encodes a network node (host, command, or peer).
    uint8 constant Node = 0x02;
    /// @dev ID encodes an asset.
    uint8 constant Asset = 0x03;

    // -------------------------------------------------------------------------
    // Account subtype tags (uint8, fourth byte of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev Admin account — chain-local, backed by an EVM address.
    uint8 constant Admin = 0x01;
    /// @dev User account — chain-agnostic, backed by an EVM address.
    uint8 constant User = 0x02;
    /// @dev Keccak account — opaque 28-byte hash of an arbitrary key.
    uint8 constant Keccak = 0x03;

    // -------------------------------------------------------------------------
    // Node subtype tags (uint8, fourth byte of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev Node is a host contract.
    uint8 constant Host = 0x01;
    /// @dev Node is a command contract.
    uint8 constant Command = 0x02;
    /// @dev Node is a peer contract.
    uint8 constant Peer = 0x03;

    // -------------------------------------------------------------------------
    // Asset subtype tags (uint8, fourth byte of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev Native chain value asset (ETH / native token).
    uint8 constant Value = 0x01;
    /// @dev ERC-20 fungible token; lower 20 bytes of the ID hold the contract address.
    uint8 constant Erc20 = 0x02;
    /// @dev ERC-721 non-fungible token; lower 20 bytes of the ID hold the issuer address.
    uint8 constant Erc721 = 0x03;
}
