// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Forms} from "./Schema.sol";

/// @title Keys
/// @notice Block type selectors for the rootzero block stream protocol.
/// Each key is the first 4 bytes of the keccak256 hash of its schema string,
/// matching the ABI-selector convention used in `Schemas`.
library Keys {
    /// @dev Empty / unset key.
    bytes4 constant Empty = bytes4(0);
    /// @dev Input amount - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Amount = bytes4(keccak256("amount(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Ledger balance - (bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Balance = bytes4(keccak256("balance(bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Host-scoped request amount - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Allocation = bytes4(keccak256("allocation(uint host, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Host-scoped allowance cap - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Allowance = bytes4(keccak256("allowance(uint host, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Cross-host custody state - (uint host, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Custody = bytes4(keccak256("custody(uint host, bytes32 asset, bytes32 meta, uint amount)"));
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
    /// @dev Frame wrapper - (bytes data); payload is schema-defined concatenated member payloads
    bytes4 constant Frame = bytes4(keccak256("frame(bytes data)"));
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
    /// @dev Transfer payout request - (bytes32 account, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Payout = bytes4(keccak256("payout(bytes32 account, bytes32 asset, bytes32 meta, uint amount)"));
    /// @dev Transfer record passed through the pipeline - (bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)
    bytes4 constant Transaction = bytes4(
        keccak256("transaction(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)")
    );
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
    /// @dev Native value relocation entry - (uint host, uint amount)
    bytes4 constant Relocation = bytes4(keccak256("relocation(uint host, uint amount)"));
    /// @dev Relayer bounty - (uint amount, bytes32 relayer)
    bytes4 constant Bounty = bytes4(keccak256("bounty(uint amount, bytes32 relayer)"));

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
