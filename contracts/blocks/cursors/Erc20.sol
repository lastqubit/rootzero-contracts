// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "./Core.sol";
import { Keys } from "../Keys.sol";
import { Assets } from "../../utils/Assets.sol";

using Assets for bytes32;

/// @title Erc20Cursors
/// @notice ERC-20-aware cursor helpers layered on top of generic block parsing.
library Erc20Cursors {
    function erc20AddrAt(uint abs) private view returns (address) {
        return Assets.erc20Addr(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Validate an AMOUNT block for any local ERC-20 token and return it.
    /// Reverts if the block is not AMOUNT or the asset is not a local ERC-20.
    /// @param cur Source cursor.
    /// @param i Byte offset of the AMOUNT block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Amount from the block.
    function expectErc20Amount(Cur memory cur, uint i) internal view returns (address token, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Amount, 96, 96);
        token = erc20AddrAt(abs);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a BALANCE block for any local ERC-20 token and return it.
    /// Reverts if the block is not BALANCE or the asset is not a local ERC-20.
    /// @param cur Source cursor.
    /// @param i Byte offset of the BALANCE block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Balance amount from the block.
    function expectErc20Balance(Cur memory cur, uint i) internal view returns (address token, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Balance, 96, 96);
        token = erc20AddrAt(abs);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a MINIMUM block for any local ERC-20 token and return it.
    /// Reverts if the block is not MINIMUM or the asset is not a local ERC-20.
    /// @param cur Source cursor.
    /// @param i Byte offset of the MINIMUM block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Minimum amount from the block.
    function expectErc20Minimum(Cur memory cur, uint i) internal view returns (address token, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Minimum, 96, 96);
        token = erc20AddrAt(abs);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a MINIMUM block for any local ERC-20 token and return it.
    /// Reverts if the current block is not MINIMUM or the asset is not a local ERC-20.
    /// @param cur Cursor; advanced past the block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Minimum amount from the block.
    function requireErc20Minimum(Cur memory cur) internal view returns (address token, uint amount) {
        (token, amount) = expectErc20Minimum(cur, cur.i);
        cur.i += 104;
    }

    /// @notice Validate a MAXIMUM block for any local ERC-20 token and return it.
    /// Reverts if the block is not MAXIMUM or the asset is not a local ERC-20.
    /// @param cur Source cursor.
    /// @param i Byte offset of the MAXIMUM block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Maximum amount from the block.
    function expectErc20Maximum(Cur memory cur, uint i) internal view returns (address token, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.Maximum, 96, 96);
        token = erc20AddrAt(abs);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a CUSTODY_AT block for any local ERC-20 token and return it.
    /// Reverts if the block is not CUSTODY_AT or the asset is not a local ERC-20.
    /// @param cur Source cursor.
    /// @param i Byte offset of the CUSTODY_AT block.
    /// @param host Expected host node ID from the block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Custodied amount from the block.
    function expectErc20CustodyAt(Cur memory cur, uint i, uint host) internal view returns (address token, uint amount) {
        (uint abs, ) = Cursors.expect(cur, i, Keys.CustodyAt, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert Cursors.UnexpectedValue();
        token = erc20AddrAt(abs + 32);
        amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume an AMOUNT block for any local ERC-20 token and return it.
    /// Reverts if the current block is not AMOUNT or the asset is not a local ERC-20.
    /// @param cur Cursor; advanced past the block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Amount from the block.
    function requireErc20Amount(Cur memory cur) internal view returns (address token, uint amount) {
        (token, amount) = expectErc20Amount(cur, cur.i);
        cur.i += 104;
    }

    /// @notice Consume a BALANCE block for any local ERC-20 token and return it.
    /// Reverts if the current block is not BALANCE or the asset is not a local ERC-20.
    /// @param cur Cursor; advanced past the block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Balance amount from the block.
    function requireErc20Balance(Cur memory cur) internal view returns (address token, uint amount) {
        (token, amount) = expectErc20Balance(cur, cur.i);
        cur.i += 104;
    }

    /// @notice Consume a MAXIMUM block for any local ERC-20 token and return it.
    /// Reverts if the current block is not MAXIMUM or the asset is not a local ERC-20.
    /// @param cur Cursor; advanced past the block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Maximum amount from the block.
    function requireErc20Maximum(Cur memory cur) internal view returns (address token, uint amount) {
        (token, amount) = expectErc20Maximum(cur, cur.i);
        cur.i += 104;
    }

    /// @notice Consume a CUSTODY_AT block for any local ERC-20 token and return it.
    /// Reverts if the current block is not CUSTODY_AT or the asset is not a local ERC-20.
    /// @param cur Cursor; advanced past the block.
    /// @param host Expected host node ID from the block.
    /// @return token Local ERC-20 token address extracted from the asset identifier.
    /// @return amount Custodied amount from the block.
    function requireErc20CustodyAt(Cur memory cur, uint host) internal view returns (address token, uint amount) {
        (token, amount) = expectErc20CustodyAt(cur, cur.i, host);
        cur.i += 136;
    }

}
