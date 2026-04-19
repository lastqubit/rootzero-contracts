// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "./Core.sol";
import { Keys } from "../Keys.sol";
import { Assets } from "../../utils/Assets.sol";

using Assets for bytes32;

/// @title Erc1155Cursors
/// @notice ERC-1155-aware cursor helpers layered on top of generic block parsing.
library Erc1155Cursors {
    /// @notice Validate an AMOUNT block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the block is not AMOUNT, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Source cursor.
    /// @param i Byte offset of the AMOUNT block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Amount from the block.
    function expectErc1155Amount(Cur memory cur, uint i, address collection) internal view returns (bytes32 meta, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Amount, 96, 96);
        bytes32(msg.data[abs:abs + 32]).matchErc1155(collection);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a BALANCE block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the block is not BALANCE, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Source cursor.
    /// @param i Byte offset of the BALANCE block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Balance amount from the block.
    function expectErc1155Balance(Cur memory cur, uint i, address collection) internal view returns (bytes32 meta, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Balance, 96, 96);
        bytes32(msg.data[abs:abs + 32]).matchErc1155(collection);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a MINIMUM block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the block is not MINIMUM, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Source cursor.
    /// @param i Byte offset of the MINIMUM block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Minimum amount from the block.
    function expectErc1155Minimum(Cur memory cur, uint i, address collection) internal view returns (bytes32 meta, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Minimum, 96, 96);
        bytes32(msg.data[abs:abs + 32]).matchErc1155(collection);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a MAXIMUM block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the block is not MAXIMUM, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Source cursor.
    /// @param i Byte offset of the MAXIMUM block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Maximum amount from the block.
    function expectErc1155Maximum(Cur memory cur, uint i, address collection) internal view returns (bytes32 meta, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Maximum, 96, 96);
        bytes32(msg.data[abs:abs + 32]).matchErc1155(collection);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a CUSTODY block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the block is not CUSTODY, the host differs, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Source cursor.
    /// @param i Byte offset of the CUSTODY block.
    /// @param host Expected host node ID from the block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Custodied amount from the block.
    function expectErc1155Custody(
        Cur memory cur,
        uint i,
        uint host,
        address collection
    ) internal view returns (bytes32 meta, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Custody, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert Cursors.UnexpectedValue();
        bytes32(msg.data[abs + 32:abs + 64]).matchErc1155(collection);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
        amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume an AMOUNT block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the current block is not AMOUNT, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Cursor; advanced past the block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Amount from the block.
    function requireErc1155Amount(Cur memory cur, address collection) internal view returns (bytes32 meta, uint amount) {
        (meta, amount) = expectErc1155Amount(cur, cur.i, collection);
        cur.i += 104;
    }

    /// @notice Consume a BALANCE block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the current block is not BALANCE, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Cursor; advanced past the block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Balance amount from the block.
    function requireErc1155Balance(Cur memory cur, address collection) internal view returns (bytes32 meta, uint amount) {
        (meta, amount) = expectErc1155Balance(cur, cur.i, collection);
        cur.i += 104;
    }

    /// @notice Consume a MINIMUM block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the current block is not MINIMUM, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Cursor; advanced past the block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Minimum amount from the block.
    function requireErc1155Minimum(Cur memory cur, address collection) internal view returns (bytes32 meta, uint amount) {
        (meta, amount) = expectErc1155Minimum(cur, cur.i, collection);
        cur.i += 104;
    }

    /// @notice Consume a MAXIMUM block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the current block is not MAXIMUM, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Cursor; advanced past the block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Maximum amount from the block.
    function requireErc1155Maximum(Cur memory cur, address collection) internal view returns (bytes32 meta, uint amount) {
        (meta, amount) = expectErc1155Maximum(cur, cur.i, collection);
        cur.i += 104;
    }

    /// @notice Consume a CUSTODY block for a specific local ERC-1155 collection and return its token id and amount.
    /// Reverts if the current block is not CUSTODY, the host differs, the asset is not a local ERC-1155, or the collection differs.
    /// @param cur Cursor; advanced past the block.
    /// @param host Expected host node ID from the block.
    /// @param collection Expected local ERC-1155 collection.
    /// @return meta Asset metadata slot from the block.
    /// @return amount Custodied amount from the block.
    function requireErc1155Custody(
        Cur memory cur,
        uint host,
        address collection
    ) internal view returns (bytes32 meta, uint amount) {
        (meta, amount) = expectErc1155Custody(cur, cur.i, host, collection);
        cur.i += 136;
    }
}
