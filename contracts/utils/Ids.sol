// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Layout} from "./Layout.sol";
import {isLocalFamily, matchesBase, toLocalBase} from "./Utils.sol";

/// @title Ids
/// @notice Encoding and decoding helpers for 256-bit node identifiers.
///
/// Node IDs share a common layout:
///   - bits [255:224] — 4-byte type prefix (`Host`, `Command`, or `Peer`)
///   - bits [223:192] — current `block.chainid` (makes IDs chain-local)
///   - bits [191:160] — 4-byte ABI selector (commands and peers only)
///   - bits [159:0]   — 160-bit EVM contract address
library Ids {
    /// @dev Thrown when an ID does not match the expected node type or chain.
    error InvalidId();

    /// @dev 24-bit family tag shared by all node types (Evm32 + Node category).
    uint24 constant Node = (uint24(Layout.Evm32) << 8) | uint24(Layout.Node);
    /// @dev Full 4-byte type prefix for host nodes.
    uint32 constant Host = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Host);
    /// @dev Full 4-byte type prefix for command nodes.
    uint32 constant Command = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Command);
    /// @dev Full 4-byte type prefix for peer nodes.
    uint32 constant Peer = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Peer);
    /// @dev Full 4-byte type prefix for query nodes.
    uint32 constant Query = (uint32(Layout.Evm32) << 16) | (uint32(Layout.Node) << 8) | uint32(Layout.Query);

    /// @notice Return true if `id` is a host node ID.
    function isHost(uint id) internal pure returns (bool) {
        return uint32(id >> 224) == Host;
    }

    /// @notice Return true if `id` is a command node ID.
    function isCommand(uint id) internal pure returns (bool) {
        return uint32(id >> 224) == Command;
    }

    /// @notice Return true if `id` is a peer node ID.
    function isPeer(uint id) internal pure returns (bool) {
        return uint32(id >> 224) == Peer;
    }

    /// @notice Return true if `id` is a query node ID.
    function isQuery(uint id) internal pure returns (bool) {
        return uint32(id >> 224) == Query;
    }

    /// @notice Assert that `id` is a command ID and return it unchanged.
    /// @param id Node ID to validate.
    /// @return cid The same `id` value if it is a command.
    function command(uint id) internal pure returns (uint cid) {
        if (!isCommand(id)) revert InvalidId();
        return id;
    }

    /// @notice Assert that `id` is a command ID and return its embedded ABI selector.
    /// @param id Node ID to validate.
    /// @return selector 4-byte command selector stored in bits [191:160].
    function commandSelector(uint id) internal pure returns (bytes4 selector) {
        if (!isCommand(id)) revert InvalidId();
        return bytes4(uint32(id >> 160));
    }

    /// @notice Assert that `id` is a peer ID and return it unchanged.
    /// @param id Node ID to validate.
    /// @return pid The same `id` value if it is a peer.
    function peer(uint id) internal pure returns (uint pid) {
        if (!isPeer(id)) revert InvalidId();
        return id;
    }

    /// @notice Assert that `id` is a peer ID and return its embedded ABI selector.
    /// @param id Node ID to validate.
    /// @return selector 4-byte peer selector stored in bits [191:160].
    function peerSelector(uint id) internal pure returns (bytes4 selector) {
        if (!isPeer(id)) revert InvalidId();
        return bytes4(uint32(id >> 160));
    }

    /// @notice Assert that `id` is a query ID and return it unchanged.
    /// @param id Node ID to validate.
    /// @return qid The same `id` value if it is a query.
    function query(uint id) internal pure returns (uint qid) {
        if (!isQuery(id)) revert InvalidId();
        return id;
    }

    /// @notice Assert that `id` is a query ID and return its embedded ABI selector.
    /// @param id Node ID to validate.
    /// @return selector 4-byte query selector stored in bits [191:160].
    function querySelector(uint id) internal pure returns (bytes4 selector) {
        if (!isQuery(id)) revert InvalidId();
        return bytes4(uint32(id >> 160));
    }

    /// @notice Assert that `id` is the host ID of `target` on the current chain.
    /// @param id Node ID to validate.
    /// @param target Expected host contract address.
    /// @return hid The same `id` value if it matches `target`.
    function host(uint id, address target) internal view returns (uint hid) {
        if (id != toHost(target)) revert InvalidId();
        return id;
    }

    /// @notice Build a chain-local host ID for `target`.
    /// @param target Host contract address.
    /// @return Host node ID on the current chain.
    function toHost(address target) internal view returns (uint) {
        return toLocalBase(Host) | uint(uint160(target));
    }

    /// @notice Build a chain-local command ID for the given selector and contract.
    /// @param selector 4-byte ABI selector of the command entry point.
    /// @param target Command contract address.
    /// @return Command node ID embedding both the selector and address.
    function toCommand(bytes4 selector, address target) internal view returns (uint) {
        uint id = toLocalBase(Command) | uint(uint160(target));
        id |= uint(uint32(selector)) << 160;
        return id;
    }

    /// @notice Build a chain-local peer ID for the given selector and contract.
    /// @param selector 4-byte ABI selector of the peer entry point.
    /// @param target Peer contract address.
    /// @return Peer node ID embedding both the selector and address.
    function toPeer(bytes4 selector, address target) internal view returns (uint) {
        uint id = toLocalBase(Peer) | uint(uint160(target));
        id |= uint(uint32(selector)) << 160;
        return id;
    }

    /// @notice Build a chain-local query ID for the given selector and contract.
    /// @param selector 4-byte ABI selector of the query entry point.
    /// @param target Query contract address.
    /// @return Query node ID embedding both the selector and address.
    function toQuery(bytes4 selector, address target) internal view returns (uint) {
        uint id = toLocalBase(Query) | uint(uint160(target));
        id |= uint(uint32(selector)) << 160;
        return id;
    }

    /// @notice Extract the contract address from any local node ID.
    /// Reverts if `id` does not belong to the local node family.
    /// @param id Node ID (host, command, or peer).
    /// @return Contract address in the lower 160 bits of `id`.
    function nodeAddr(uint id) internal view returns (address) {
        if (!isLocalFamily(id, Node)) revert InvalidId();
        return address(uint160(id));
    }

    /// @notice Extract the contract address from a local host ID.
    /// Reverts if `id` does not match the local host base.
    /// @param id Host node ID.
    /// @return Host contract address in the lower 160 bits of `id`.
    function hostAddr(uint id) internal view returns (address) {
        if (!matchesBase(bytes32(id), toLocalBase(Host))) revert InvalidId();
        return address(uint160(id));
    }
}

/// @title Selectors
/// @notice ABI-selector derivation helpers for command, peer, and query dispatch.
library Selectors {
    /// @dev ABI argument encoding for command entry points: `((uint256,bytes32,bytes,bytes))`.
    string constant CommandArgs = "((uint256,bytes32,bytes,bytes))";
    /// @dev ABI argument encoding for peer entry points: `(bytes)`.
    string constant PeerArgs = "(bytes)";
    /// @dev ABI argument encoding for query entry points: `(bytes)`.
    string constant QueryArgs = "(bytes)";

    /// @notice Derive the 4-byte ABI selector for a named command.
    /// The selector is `keccak256(name ++ CommandArgs)[0:4]`.
    /// @param name Command function name (without arguments).
    /// @return 4-byte selector.
    function command(string memory name) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes.concat(bytes(name), bytes(CommandArgs))));
    }

    /// @notice Derive the 4-byte ABI selector for a named peer.
    /// The selector is `keccak256(name ++ PeerArgs)[0:4]`.
    /// @param name Peer function name (without arguments).
    /// @return 4-byte selector.
    function peer(string memory name) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes.concat(bytes(name), bytes(PeerArgs))));
    }

    /// @notice Derive the 4-byte ABI selector for a named query.
    /// The selector is `keccak256(name ++ QueryArgs)[0:4]`.
    /// @param name Query function name (without arguments).
    /// @return 4-byte selector.
    function query(string memory name) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes.concat(bytes(name), bytes(QueryArgs))));
    }
}
