// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Layout
/// @notice Single-byte and two-byte tag constants that describe the encoding
/// layout of 256-bit IDs used throughout the rootzero protocol.
///
/// IDs are structured as:
///   `[uint32 type][uint32 chainid][192-bit payload]`
/// where `type` is `[uint8 vm][uint8 width][uint8 category][uint8 subtype]`.
library Layout {
    // -------------------------------------------------------------------------
    // VM and data-width tags (top 2 bytes of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev EVM-compatible value; payloads are built around 20-byte addresses.
    uint8 constant Evm = 0x01;
    /// @dev 32-byte ID; no paired metadata word is required.
    uint8 constant Width32 = 0x20;
    /// @dev 64-byte ID; a paired metadata word completes the identity.
    uint8 constant Width64 = 0x40;

    /// @dev 32-byte EVM-compatible value; lower 20 bytes hold an address.
    uint16 constant Evm32 = (uint16(Evm) << 8) | uint16(Width32);
    /// @dev 64-byte EVM-compatible value; used when a paired metadata word completes the identity.
    uint16 constant Evm64 = (uint16(Evm) << 8) | uint16(Width64);

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
    /// @dev Guardian account — chain-local, backed by an EVM address.
    uint8 constant Guardian = 0x02;
    /// @dev User account — chain-agnostic, backed by an EVM address.
    uint8 constant User = 0x03;
    // -------------------------------------------------------------------------
    // Node subtype tags (uint8, fourth byte of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev Node is a chain/domain identifier.
    uint8 constant Chain = 0x01;
    /// @dev Node is a host contract.
    uint8 constant Host = 0x02;
    /// @dev Node is a command contract.
    uint8 constant Command = 0x03;
    /// @dev Node is a peer contract.
    uint8 constant Peer = 0x04;
    /// @dev Node is a query contract.
    uint8 constant Query = 0x05;
    /// @dev Node is a guardian-only direct action.
    uint8 constant Guard = 0x06;

    // -------------------------------------------------------------------------
    // Asset subtype tags (uint8, fourth byte of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev Native chain value asset (ETH / native token).
    uint8 constant Value = 0x01;
    /// @dev ERC-20 fungible token; lower 20 bytes of the ID hold the contract address.
    uint8 constant Erc20 = 0x02;
    /// @dev ERC-721 non-fungible token; lower 20 bytes of the ID hold the collection address.
    uint8 constant Erc721 = 0x03;
    /// @dev ERC-1155 multi-token asset; lower 20 bytes of the ID hold the collection address.
    uint8 constant Erc1155 = 0x04;
}
