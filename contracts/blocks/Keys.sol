// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Keys
/// @notice Block type selectors for the rootzero block stream protocol.
/// Each key is the first 4 bytes of the keccak256 hash of its schema string,
/// matching the ABI-selector convention used in `Schemas`.
library Keys {
    /// @dev Input amount — (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Amount = bytes4(keccak256("amount(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Ledger balance — (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Balance = bytes4(keccak256("balance(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Cross-host custody position — (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Custody = bytes4(keccak256("custody(uint host, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Minimum acceptable output — (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Minimum = bytes4(keccak256("minimum(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Maximum allowable spend — (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Maximum = bytes4(keccak256("maximum(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Hard stop / iteration sentinel — ()
    bytes4 constant Break = bytes4(keccak256("break()"));
    /// @dev Bundle wrapper — (bytes data); payload is an embedded block stream
    bytes4 constant Bundle = bytes4(keccak256("bundle(bytes data)"));
    /// @dev Extensible routing field — (bytes data); layout is command-defined
    bytes4 constant Route = bytes4(keccak256("route(bytes data)"));
    /// @dev Plain scalar amount — (uint amount)
    bytes4 constant Quantity = bytes4(keccak256("quantity(uint amount)"));
    /// @dev Ratio or rate value — (uint value)
    bytes4 constant Rate = bytes4(keccak256("rate(uint value)"));
    /// @dev Counter-party account — (bytes32 account)
    bytes4 constant Party = bytes4(keccak256("party(bytes32 account)"));
    /// @dev Destination account — (bytes32 account)
    bytes4 constant Recipient = bytes4(keccak256("recipient(bytes32 account)"));
    /// @dev Transfer record passed through the pipeline — (bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Transaction = bytes4(keccak256("tx(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Sub-command invocation — (uint target, uint value, bytes request)
    bytes4 constant Step = bytes4(keccak256("step(uint target, uint value, bytes request)"));
    /// @dev Authentication proof — (uint cid, uint deadline, bytes proof); must appear last in its segment
    bytes4 constant Auth = bytes4(keccak256("auth(uint cid, uint deadline, bytes proof)"));
    /// @dev Asset descriptor without amount — (bytes32 asset, bytes32 meta)
    bytes4 constant Asset = bytes4(keccak256("asset(bytes32 asset, bytes32 meta)"));
    /// @dev Node identifier — (uint id)
    bytes4 constant Node = bytes4(keccak256("node(uint id)"));
    /// @dev Cross-host asset listing — (uint host, bytes32 asset, bytes32 meta)
    bytes4 constant Listing = bytes4(keccak256("listing(uint host, bytes32 asset, bytes32 meta)"));
    /// @dev Liquidity funding entry — (uint host, uint amount)
    bytes4 constant Funding = bytes4(keccak256("funding(uint host, uint amount)"));
    /// @dev Cross-host allocation — (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Allocation = bytes4(keccak256("allocation(uint host, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Relayer bounty — (uint amount, bytes32 relayer)
    bytes4 constant Bounty = bytes4(keccak256("bounty(uint amount, bytes32 relayer)"));
}
