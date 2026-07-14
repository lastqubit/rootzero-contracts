// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Keys
/// @notice Standard block type selectors for the rootzero block stream protocol.
/// Standard keys use the first 4 bytes of `keccak256("#name")` by convention.
/// Custom block keys only need to be unique in the context where they are used;
/// hosts may publish custom key meanings with the `Schema` event.
library Keys {
    /// @notice Create a context-local block key.
    /// @dev Local keys are opaque tags for host- or endpoint-specific schemas.
    /// The caller is responsible for choosing values that are unique in the
    /// context where they are used and publishing their meaning with `Schema`.
    /// @param value Opaque local key value.
    /// @return Context-local block key.
    function local(uint32 value) internal pure returns (bytes4) {
        return bytes4(value);
    }

    /// @dev Empty / unset key.
    bytes4 constant Empty = bytes4(0);
    /// @dev Wildcard key used in discovery when any block stream is accepted.
    bytes4 constant Any = 0xffffffff;
    /// @dev Input amount - (bytes32 asset, uint amount)
    bytes4 constant Amount = bytes4(keccak256("#amount"));
    /// @dev Ledger balance - (bytes32 asset, uint amount)
    bytes4 constant Balance = bytes4(keccak256("#balance"));
    /// @dev Balance constraint - (bytes32 asset, uint min, uint max)
    bytes4 constant BalanceLimit = bytes4(keccak256("#balanceLimit"));
    /// @dev Host-scoped request amount - (uint host, bytes32 asset, uint amount)
    bytes4 constant Allocation = bytes4(keccak256("#allocation"));
    /// @dev Host-scoped allowance cap - (uint host, bytes32 asset, uint amount)
    bytes4 constant Allowance = bytes4(keccak256("#allowance"));
    /// @dev Cross-host custody state - (uint host, bytes32 asset, uint amount)
    bytes4 constant Custody = bytes4(keccak256("#custody"));
    /// @dev Cross-host custody constraint - (uint host, bytes32 asset, uint min, uint max)
    bytes4 constant CustodyLimit = bytes4(keccak256("#custodyLimit"));
    /// @dev Fee amount - (uint amount)
    bytes4 constant Fee = bytes4(keccak256("#fee"));
    /// @dev List wrapper; payload is an embedded repeated block stream
    bytes4 constant List = bytes4(keccak256("#list"));
    /// @dev EVM-encoded payload field; layout follows standard ABI tuple encoding
    bytes4 constant Evm = bytes4(keccak256("#evm"));
    /// @dev Reserved raw bytes child block.
    bytes4 constant Bytes = bytes4(keccak256("#bytes"));
    /// @dev Reserved UTF-8 string child block.
    bytes4 constant String = bytes4(keccak256("#string"));
    /// @dev Account identifier - (bytes32 account)
    bytes4 constant Account = bytes4(keccak256("#account"));
    /// @dev Transfer record passed through the pipeline - (bytes32 from, bytes32 to, bytes32 asset, uint amount)
    bytes4 constant Transaction = bytes4(keccak256("#transaction"));
    /// @dev Sub-command invocation - (uint target, uint resources, #bytes as request)
    bytes4 constant Step = bytes4(keccak256("#step"));
    /// @dev Portal relay request - (uint portal, uint resources, #bytes as request)
    bytes4 constant Relay = bytes4(keccak256("#relay"));
    /// @dev Command context transport - (bytes32 account, #bytes as state, #bytes as request)
    bytes4 constant Context = bytes4(keccak256("#context"));
    /// @dev Recoverable witness - (uint handler, uint resources, bytes32 key, #bytes as witness)
    bytes4 constant Recover = bytes4(keccak256("#recover"));
    /// @dev Portal encoded payload dispatch - (uint portal, uint resources, #bytes as payload)
    bytes4 constant Dispatch = bytes4(keccak256("#dispatch"));
    /// @dev Raw external call - (uint target, uint resources, #bytes as payload)
    bytes4 constant Call = bytes4(keccak256("#call"));
    /// @dev Authentication proof - (uint cid, uint deadline, #bytes as proof); must appear last in its segment
    bytes4 constant Auth = bytes4(keccak256("#auth"));
    /// @dev Asset descriptor without amount - (bytes32 asset)
    bytes4 constant Asset = bytes4(keccak256("#asset"));
    /// @dev Node identifier - (uint id)
    bytes4 constant Node = bytes4(keccak256("#node"));
    /// @dev Relayer bounty - (uint amount, bytes32 relayer)
    bytes4 constant Bounty = bytes4(keccak256("#bounty"));
    /// @dev Mutable node label - (uint id, bytes32 namespace, #string as name)
    bytes4 constant Label = bytes4(keccak256("#label"));

    /// @dev Structural status form - (uint code)
    bytes4 constant Status = bytes4(keccak256("#status"));
    /// @dev Structural asset amount form - (bytes32 asset, uint amount)
    bytes4 constant AssetAmount = bytes4(keccak256("#assetAmount"));
    /// @dev Structural account asset form - (bytes32 account, bytes32 asset)
    bytes4 constant AccountAsset = bytes4(keccak256("#accountAsset"));
    /// @dev Structural account amount form - (bytes32 account, bytes32 asset, uint amount)
    bytes4 constant AccountAmount = bytes4(keccak256("#accountAmount"));
    /// @dev Structural host amount form - (uint host, bytes32 asset, uint amount)
    bytes4 constant HostAmount = bytes4(keccak256("#hostAmount"));
    /// @dev Structural host account asset form - (uint host, bytes32 account, bytes32 asset)
    bytes4 constant HostAccountAsset = bytes4(keccak256("#hostAccountAsset"));
    /// @dev Structural host account amount form - (uint host, bytes32 account, bytes32 asset, uint amount)
    bytes4 constant HostAccountAmount = bytes4(keccak256("#hostAccountAmount"));
}
