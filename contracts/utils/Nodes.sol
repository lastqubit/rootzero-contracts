// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Layout} from "./Layout.sol";
import {ensureAddr, isFamily, matchesBase, toLocalBase} from "./Utils.sol";

/// @title Nodes
/// @notice Encoding and decoding helpers for 256-bit node identifiers.
///
/// Node IDs share a common layout:
///   - bits [255:224] — 4-byte type prefix (`Host`, `Command`, or `Peer`)
///   - bits [223:192] — current `block.chainid` (makes IDs chain-local)
///   - bits [191:160] — 4-byte ABI selector (commands and peers only)
///   - bits [159:0]   — 160-bit EVM contract address
///
/// If the first byte is zero, the node is an opaque
/// `0x00 || bytes31(hash)` ID. The callable target must be resolved by lookup
/// or witness data before dispatch.
///
/// The helpers in this library validate and deconstruct structured node IDs.
library Nodes {
    /// @dev Thrown when an ID does not match the expected node type or chain.
    error InvalidId();

    /// @dev 24-bit family tag shared by all node types (Evm + Node category).
    uint24 constant Family = (uint24(Layout.Evm) << 8) | uint24(Layout.Node);
    /// @dev Full 4-byte type prefix for chain/domain nodes.
    uint32 constant Chain = (uint32(Layout.Evm) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Chain);
    /// @dev Full 4-byte type prefix for host nodes.
    uint32 constant Host = (uint32(Layout.Evm) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Host);
    /// @dev Full 4-byte type prefix for command nodes.
    uint32 constant Command = (uint32(Layout.Evm) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Command);
    /// @dev Full 4-byte type prefix for peer nodes.
    uint32 constant Peer = (uint32(Layout.Evm) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Peer);
    /// @dev Full 4-byte type prefix for query nodes.
    uint32 constant Query = (uint32(Layout.Evm) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Query);
    /// @dev Full 4-byte type prefix for guard action nodes.
    uint32 constant Guard = (uint32(Layout.Evm) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Guard);

    /// @notice Return true if `node` is a host node ID.
    function isHost(uint node) internal pure returns (bool) {
        return uint32(node >> 224) == Host;
    }

    /// @notice Return true if `node` is a command node ID.
    function isCommand(uint node) internal pure returns (bool) {
        return uint32(node >> 224) == Command;
    }

    /// @notice Return true if `node` is a peer node ID.
    function isPeer(uint node) internal pure returns (bool) {
        return uint32(node >> 224) == Peer;
    }

    /// @notice Return true if `node` is a query node ID.
    function isQuery(uint node) internal pure returns (bool) {
        return uint32(node >> 224) == Query;
    }

    /// @notice Return true if `node` is a guard action node ID.
    function isGuard(uint node) internal pure returns (bool) {
        return uint32(node >> 224) == Guard;
    }

    /// @notice Return true if `node` belongs to the EVM node family.
    function isEvm(uint node) internal pure returns (bool) {
        return isFamily(node, Family);
    }

    /// @notice Return true if `node` belongs to the EVM node family on the current chain.
    function isLocal(uint node) internal view returns (bool) {
        return isEvm(node) && uint32(node >> 192) == block.chainid;
    }

    /// @notice Assert that `value` is a host node ID and return it as a node.
    /// @param value Value to validate.
    /// @return node The same `value` if it is a host node.
    function host(uint value) internal pure returns (uint node) {
        if (!isHost(value)) revert InvalidId();
        return value;
    }

    /// @notice Assert that `value` is a command node ID and return it as a node.
    /// @param value Value to validate.
    /// @return node The same `value` if it is a command node.
    function command(uint value) internal pure returns (uint node) {
        if (!isCommand(value)) revert InvalidId();
        return value;
    }

    /// @notice Assert that `value` is a peer node ID and return it as a node.
    /// @param value Value to validate.
    /// @return node The same `value` if it is a peer node.
    function peer(uint value) internal pure returns (uint node) {
        if (!isPeer(value)) revert InvalidId();
        return value;
    }

    /// @notice Assert that `value` is a query node ID and return it as a node.
    /// @param value Value to validate.
    /// @return node The same `value` if it is a query node.
    function query(uint value) internal pure returns (uint node) {
        if (!isQuery(value)) revert InvalidId();
        return value;
    }

    /// @notice Assert that `value` is a guard action node ID and return it as a node.
    /// @param value Value to validate.
    /// @return node The same `value` if it is a guard action node.
    function guard(uint value) internal pure returns (uint node) {
        if (!isGuard(value)) revert InvalidId();
        return value;
    }

    /// @notice Assert that `value` belongs to the EVM node family and return it as a node.
    /// @param value Value to validate.
    /// @return node The same `value` if it is an EVM node.
    function evm(uint value) internal pure returns (uint node) {
        if (!isEvm(value)) revert InvalidId();
        return value;
    }

    /// @notice Assert that `value` belongs to the EVM node family on the current chain and return it as a node.
    /// @param value Value to validate.
    /// @return node The same `value` if it is local.
    function local(uint value) internal view returns (uint node) {
        if (!isLocal(value)) revert InvalidId();
        return value;
    }

    /// @notice Assert that `node` is a command ID and return its embedded ABI selector.
    /// @param node Node ID to validate.
    /// @return selector 4-byte command selector stored in bits [191:160].
    function commandSelector(uint node) internal pure returns (bytes4 selector) {
        return bytes4(uint32(command(node) >> 160));
    }

    /// @notice Assert that `node` is a peer ID and return its embedded ABI selector.
    /// @param node Node ID to validate.
    /// @return selector 4-byte peer selector stored in bits [191:160].
    function peerSelector(uint node) internal pure returns (bytes4 selector) {
        return bytes4(uint32(peer(node) >> 160));
    }

    /// @notice Assert that `node` is a query ID and return its embedded ABI selector.
    /// @param node Node ID to validate.
    /// @return selector 4-byte query selector stored in bits [191:160].
    function querySelector(uint node) internal pure returns (bytes4 selector) {
        return bytes4(uint32(query(node) >> 160));
    }

    /// @notice Assert that `node` is a guard action ID and return its embedded ABI selector.
    /// @param node Node ID to validate.
    /// @return selector 4-byte guard selector stored in bits [191:160].
    function guardSelector(uint node) internal pure returns (bytes4 selector) {
        return bytes4(uint32(guard(node) >> 160));
    }

    /// @notice Assert that `value` is the host node of `target` on the current chain.
    /// @param value Value to validate.
    /// @param target Expected host contract address.
    /// @return node The same `value` if it matches `target`.
    function matchHost(uint value, address target) internal view returns (uint node) {
        if (value != toHost(target)) revert InvalidId();
        return value;
    }

    /// @notice Build the chain node ID for the current chain.
    /// @return node Chain node ID with zero selector and `address(0)` payload.
    function localChain() internal view returns (uint node) {
        return toLocalBase(Chain);
    }

    /// @notice Build a chain-local host ID for `target`.
    /// @param target Host contract address.
    /// @return node Host node ID on the current chain.
    function toHost(address target) internal view returns (uint node) {
        return toLocalBase(Host) | uint(uint160(target));
    }

    /// @notice Build a chain-local command ID for the given selector and contract.
    /// @param selector 4-byte ABI selector of the command entry point.
    /// @param target Command contract address.
    /// @return node Command node ID embedding both the selector and address.
    function toCommand(bytes4 selector, address target) internal view returns (uint node) {
        node = toLocalBase(Command) | uint(uint160(target));
        node |= uint(uint32(selector)) << 160;
    }

    /// @notice Build a chain-local peer ID for the given selector and contract.
    /// @param selector 4-byte ABI selector of the peer entry point.
    /// @param target Peer contract address.
    /// @return node Peer node ID embedding both the selector and address.
    function toPeer(bytes4 selector, address target) internal view returns (uint node) {
        node = toLocalBase(Peer) | uint(uint160(target));
        node |= uint(uint32(selector)) << 160;
    }

    /// @notice Build a chain-local query ID for the given selector and contract.
    /// @param selector 4-byte ABI selector of the query entry point.
    /// @param target Query contract address.
    /// @return node Query node ID embedding both the selector and address.
    function toQuery(bytes4 selector, address target) internal view returns (uint node) {
        node = toLocalBase(Query) | uint(uint160(target));
        node |= uint(uint32(selector)) << 160;
    }

    /// @notice Build a chain-local guard action ID for the given selector and contract.
    /// @param selector 4-byte ABI selector of the guard action entry point.
    /// @param target Guard action contract address.
    /// @return node Guard action node ID embedding both the selector and address.
    function toGuard(bytes4 selector, address target) internal view returns (uint node) {
        node = toLocalBase(Guard) | uint(uint160(target));
        node |= uint(uint32(selector)) << 160;
    }

    /// @notice Extract the contract address from any local node ID.
    /// Reverts if `node` does not belong to the local node family or carries `address(0)`.
    /// @param node Node ID.
    /// @return Contract address in the lower 160 bits of `node`.
    function addr(uint node) internal view returns (address) {
        return ensureAddr(address(uint160(local(node))));
    }

    /// @notice Extract the contract address from a local host ID.
    /// Reverts if `node` does not match the local host base or carries `address(0)`.
    /// @param node Host node ID.
    /// @return Host contract address in the lower 160 bits of `node`.
    function hostAddr(uint node) internal view returns (address) {
        if (!matchesBase(bytes32(node), toLocalBase(Host))) revert InvalidId();
        return ensureAddr(address(uint160(node)));
    }
}
