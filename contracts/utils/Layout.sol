// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Layout
/// @notice Single-byte and two-byte tag constants that describe the encoding
/// layout of 256-bit IDs used throughout the rootzero protocol.
///
/// IDs are structured as:
///   `[uint32 type][uint32 chainid][192-bit payload]`
/// where `type` is `[uint16 representation][uint8 category][uint8 subtype]`.
///
/// Values whose first byte is zero are opaque IDs:
///   `[0x00][bytes31 truncated hash]`
/// They require lookup or witness data when the native preimage is needed.
/// Opaque preimages start with a one-byte format/hash tag. `0x01` means the ID
/// is `0x00 || bytes31(keccak256(preimage))`; remaining bytes are host/domain-specific.
/// Values whose first byte is nonzero follow the structured layout above.
library Layout {
    // -------------------------------------------------------------------------
    // Representation tags (top 2 bytes of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev EVM-compatible ID; lower 20 payload bytes hold an address when present.
    uint16 constant Evm = 0x0120;

    // -------------------------------------------------------------------------
    // Category tags (uint8, third byte of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev ID encodes an account.
    uint8 constant Account = 0x01;
    /// @dev ID encodes a network node (host, command, port, query, or guard).
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
    /// @dev Node is a port callable by trusted peer hosts.
    uint8 constant Port = 0x04;
    /// @dev Node is a query contract.
    uint8 constant Query = 0x05;
    /// @dev Node is a guardian-only direct action.
    uint8 constant Guard = 0x06;

    // -------------------------------------------------------------------------
    // Asset subtype tags (uint8, fourth byte of the ID type field)
    // -------------------------------------------------------------------------

    /// @dev Native chain coin/token asset.
    uint8 constant Native = 0x01;
    /// @dev ERC-20 fungible token; lower 20 bytes of the ID hold the contract address.
    uint8 constant Erc20 = 0x02;
}
