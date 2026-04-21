// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Keys
/// @notice Block type selectors for the rootzero block stream protocol.
/// Each key is the first 4 bytes of the keccak256 hash of its schema string,
/// matching the ABI-selector convention used in `Schemas`.
library Keys {
    /// @dev Input amount - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Amount = bytes4(keccak256("amount(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Ledger balance - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Balance = bytes4(keccak256("balance(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Host-qualified custody position - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant CustodyAt = bytes4(keccak256("custodyAt(uint host, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Minimum acceptable output - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Minimum = bytes4(keccak256("minimum(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Maximum allowable spend - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Maximum = bytes4(keccak256("maximum(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Signed min/max bounds - (int min, int max)
    bytes4 constant Bounds = bytes4(keccak256("bounds(int min, int max)"));
    /// @dev Fee amount - (uint amount)
    bytes4 constant Fee = bytes4(keccak256("fee(uint amount)"));
    /// @dev Hard stop / iteration sentinel - ()
    bytes4 constant Break = bytes4(keccak256("break()"));
    /// @dev Bundle wrapper - (bytes data); payload is an embedded block stream
    bytes4 constant Bundle = bytes4(keccak256("bundle(bytes data)"));
    /// @dev List wrapper - (bytes data); payload is an embedded repeated block stream
    bytes4 constant List = bytes4(keccak256("list(bytes data)"));
    /// @dev Extensible routing field - (bytes data); layout is command-defined
    bytes4 constant Route = bytes4(keccak256("route(bytes data)"));
    /// @dev Extensible list item field - (bytes data); layout is implementation-defined
    bytes4 constant Item = bytes4(keccak256("item(bytes data)"));
    /// @dev EVM-encoded payload field - (bytes data); layout follows standard ABI tuple encoding
    bytes4 constant Evm = bytes4(keccak256("evm(bytes data)"));
    /// @dev Extensible query field - (bytes data); layout is query-defined, key is always `Keys.Query`
    bytes4 constant Query = bytes4(keccak256("query(bytes data)"));
    /// @dev Extensible response field - (bytes data); layout is response-defined, key is always `Keys.Response`
    bytes4 constant Response = bytes4(keccak256("response(bytes data)"));
    /// @dev Plain scalar amount - (uint amount)
    bytes4 constant Quantity = bytes4(keccak256("quantity(uint amount)"));
    /// @dev Ratio or rate value - (uint value)
    bytes4 constant Rate = bytes4(keccak256("rate(uint value)"));
    /// @dev Account identifier - (bytes32 account)
    bytes4 constant Account = bytes4(keccak256("account(bytes32 account)"));
    /// @dev Account asset position key - (bytes32 account, bytes32 asset, bytes32 meta)
    bytes4 constant Position = bytes4(keccak256("position(bytes32 account, bytes32 asset, bytes32 meta)"));
    /// @dev Host-qualified account asset position key - (uint host, bytes32 account, bytes32 asset, bytes32 meta)
    bytes4 constant PositionAt = bytes4(keccak256("positionAt(uint host, bytes32 account, bytes32 asset, bytes32 meta)"));
    /// @dev Account asset entry - (bytes32 account, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Entry = bytes4(keccak256("entry(bytes32 account, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Host-qualified account asset entry - (uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant EntryAt = bytes4(keccak256("entryAt(uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Transfer record passed through the pipeline - (bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Transaction = bytes4(keccak256("tx(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Sub-command invocation - (uint target, uint value, bytes request)
    bytes4 constant Step = bytes4(keccak256("step(uint target, uint value, bytes request)"));
    /// @dev Raw external call - (uint target, uint value, bytes data)
    bytes4 constant Call = bytes4(keccak256("call(uint target, uint value, bytes data)"));
    /// @dev Authentication proof - (uint cid, uint deadline, bytes proof); must appear last in its segment
    bytes4 constant Auth = bytes4(keccak256("auth(uint cid, uint deadline, bytes proof)"));
    /// @dev Asset descriptor without amount - (bytes32 asset, bytes32 meta)
    bytes4 constant Asset = bytes4(keccak256("asset(bytes32 asset, bytes32 meta)"));
    /// @dev Node identifier - (uint id)
    bytes4 constant Node = bytes4(keccak256("node(uint id)"));
    /// @dev Liquidity funding entry - (uint host, uint amount)
    bytes4 constant Funding = bytes4(keccak256("funding(uint host, uint amount)"));
    /// @dev Host-qualified allocation - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Allocation = bytes4(keccak256("allocation(uint host, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Relayer bounty - (uint amount, bytes32 relayer)
    bytes4 constant Bounty = bytes4(keccak256("bounty(uint amount, bytes32 relayer)"));
}
