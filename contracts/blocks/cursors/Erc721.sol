// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "./Core.sol";
import { Keys } from "../Keys.sol";
import { Assets } from "../../utils/Assets.sol";

using Assets for bytes32;

/// @title Erc721Cursors
/// @notice ERC-721-aware cursor helpers layered on top of generic block parsing.
library Erc721Cursors {
    /// @notice Validate a BALANCE block for a specific local ERC-721 collection and return its metadata.
    /// Reverts if the block is not BALANCE, the asset is not a local ERC-721, the collection differs, or the amount is not 1.
    /// @param cur Source cursor.
    /// @param i Byte offset of the BALANCE block.
    /// @param collection Expected local ERC-721 collection.
    /// @return meta Asset metadata slot from the block.
    function expectErc721Balance(Cur memory cur, uint i, address collection) internal view returns (bytes32 meta) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Balance, 96, 96);
        bytes32(msg.data[abs:abs + 32]).matchErc721(collection);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        if (uint(bytes32(msg.data[abs + 64:abs + 96])) != 1) revert Cursors.UnexpectedValue();
    }

    /// @notice Validate a CUSTODY block for a specific local ERC-721 collection and return its metadata.
    /// Reverts if the block is not CUSTODY, the host differs, the asset is not a local ERC-721, the collection differs, or the amount is not 1.
    /// @param cur Source cursor.
    /// @param i Byte offset of the CUSTODY block.
    /// @param host Expected host node ID from the block.
    /// @param collection Expected local ERC-721 collection.
    /// @return meta Asset metadata slot from the block.
    function expectErc721Custody(
        Cur memory cur,
        uint i,
        uint host,
        address collection
    ) internal view returns (bytes32 meta) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Custody, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert Cursors.UnexpectedValue();
        bytes32(msg.data[abs + 32:abs + 64]).matchErc721(collection);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
        if (uint(bytes32(msg.data[abs + 96:abs + 128])) != 1) revert Cursors.UnexpectedValue();
    }

    /// @notice Consume a BALANCE block for a specific local ERC-721 collection and return its metadata.
    /// Reverts if the current block is not BALANCE, the asset is not a local ERC-721, the collection differs, or the amount is not 1.
    /// @param cur Cursor; advanced past the block.
    /// @param collection Expected local ERC-721 collection.
    /// @return meta Asset metadata slot from the block.
    function requireErc721Balance(Cur memory cur, address collection) internal view returns (bytes32 meta) {
        meta = expectErc721Balance(cur, cur.i, collection);
        cur.i += 104;
    }

    /// @notice Consume a CUSTODY block for a specific local ERC-721 collection and return its metadata.
    /// Reverts if the current block is not CUSTODY, the host differs, the asset is not a local ERC-721, the collection differs, or the amount is not 1.
    /// @param cur Cursor; advanced past the block.
    /// @param host Expected host node ID from the block.
    /// @param collection Expected local ERC-721 collection.
    /// @return meta Asset metadata slot from the block.
    function requireErc721Custody(Cur memory cur, uint host, address collection) internal view returns (bytes32 meta) {
        meta = expectErc721Custody(cur, cur.i, host, collection);
        cur.i += 136;
    }
}
