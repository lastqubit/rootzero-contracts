// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Forms, Schemas} from "./Schema.sol";

/// @title Keys
/// @notice Block type selectors for the rootzero block stream protocol.
/// Each key is the first 4 bytes of the keccak256 hash of its schema string,
/// matching the ABI-selector convention used in `Schemas`.
library Keys {
    /// @dev Empty / unset key.
    bytes4 constant Empty = bytes4(0);
    /// @dev Input amount - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Amount = bytes4(keccak256(bytes(Schemas.Amount)));
    /// @dev Ledger balance - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Balance = bytes4(keccak256(bytes(Schemas.Balance)));
    /// @dev Host-scoped request amount - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Allocation = bytes4(keccak256(bytes(Schemas.Allocation)));
    /// @dev Host-scoped allowance cap - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Allowance = bytes4(keccak256(bytes(Schemas.Allowance)));
    /// @dev Cross-host custody state - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Custody = bytes4(keccak256(bytes(Schemas.Custody)));
    /// @dev Minimum acceptable output - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Minimum = bytes4(keccak256(bytes(Schemas.Minimum)));
    /// @dev Maximum allowable spend - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Maximum = bytes4(keccak256(bytes(Schemas.Maximum)));
    /// @dev Signed min/max bounds - (int min, int max)
    bytes4 constant Bounds = bytes4(keccak256(bytes(Schemas.Bounds)));
    /// @dev Fee amount - (uint amount)
    bytes4 constant Fee = bytes4(keccak256(bytes(Schemas.Fee)));
    /// @dev Hard stop / iteration sentinel - ()
    bytes4 constant Break = bytes4(keccak256(bytes(Schemas.Break)));
    /// @dev List wrapper - (bytes payload); payload is an embedded repeated block stream
    bytes4 constant List = bytes4(keccak256(bytes(Schemas.List)));
    /// @dev Frame wrapper - (bytes payload); payload is schema-defined fields, optionally followed by block-stream items
    bytes4 constant Frame = bytes4(keccak256(bytes(Schemas.Frame)));
    /// @dev Extensible data field - (bytes payload); layout is schema-defined
    bytes4 constant Data = bytes4(keccak256(bytes(Schemas.Data)));
    /// @dev EVM-encoded payload field - (bytes payload); layout follows standard ABI tuple encoding
    bytes4 constant Evm = bytes4(keccak256(bytes(Schemas.Evm)));
    /// @dev Extensible query field - (bytes payload); layout is query-defined, key is always `Keys.Query`
    bytes4 constant Query = bytes4(keccak256(bytes(Schemas.Query)));
    /// @dev Extensible response field - (bytes payload); layout is response-defined, key is always `Keys.Response`
    bytes4 constant Response = bytes4(keccak256(bytes(Schemas.Response)));
    /// @dev Plain scalar amount - (uint amount)
    bytes4 constant Quantity = bytes4(keccak256(bytes(Schemas.Quantity)));
    /// @dev Ratio or rate value - (uint value)
    bytes4 constant Rate = bytes4(keccak256(bytes(Schemas.Rate)));
    /// @dev Account identifier - (bytes32 account)
    bytes4 constant Account = bytes4(keccak256(bytes(Schemas.Account)));
    /// @dev Transfer payout request - (bytes32 account, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Payout = bytes4(keccak256(bytes(Schemas.Payout)));
    /// @dev Transfer record passed through the pipeline - (bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Transaction = bytes4(keccak256(bytes(Schemas.Transaction)));
    /// @dev Sub-command invocation - (uint target, uint value, bytes request)
    bytes4 constant Step = bytes4(keccak256(bytes(Schemas.Step)));
    /// @dev Raw external call - (uint target, uint value, bytes payload)
    bytes4 constant Call = bytes4(keccak256(bytes(Schemas.Call)));
    /// @dev Authentication proof - (uint cid, uint deadline, bytes proof); must appear last in its segment
    bytes4 constant Auth = bytes4(keccak256(bytes(Schemas.Auth)));
    /// @dev Asset descriptor without amount - (bytes32 asset, bytes32 meta)
    bytes4 constant Asset = bytes4(keccak256(bytes(Schemas.Asset)));
    /// @dev Node identifier - (uint id)
    bytes4 constant Node = bytes4(keccak256(bytes(Schemas.Node)));
    /// @dev Relayer bounty - (uint amount, bytes32 relayer)
    bytes4 constant Bounty = bytes4(keccak256(bytes(Schemas.Bounty)));

    /// @dev Structural status form - (bool ok)
    bytes4 constant Status = bytes4(keccak256(bytes(Forms.Status)));
    /// @dev Structural asset amount form - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant AssetAmount = bytes4(keccak256(bytes(Forms.AssetAmount)));
    /// @dev Structural account asset form - (bytes32 account, bytes32 asset, bytes32 meta)
    bytes4 constant AccountAsset = bytes4(keccak256(bytes(Forms.AccountAsset)));
    /// @dev Structural account amount form - (bytes32 account, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant AccountAmount = bytes4(keccak256(bytes(Forms.AccountAmount)));
    /// @dev Structural host amount form - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant HostAmount = bytes4(keccak256(bytes(Forms.HostAmount)));
    /// @dev Structural host account asset form - (uint host, bytes32 account, bytes32 asset, bytes32 meta)
    bytes4 constant HostAccountAsset = bytes4(keccak256(bytes(Forms.HostAccountAsset)));
    /// @dev Structural host account amount form - (uint host, bytes32 account, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant HostAccountAmount = bytes4(keccak256(bytes(Forms.HostAccountAmount)));
}
