// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, Cursors, Cursor, HostAmount, Keys, Writer, Writers } from "../Cursors.sol";

using Cursors for Cursor;
using Writers for Writer;

string constant ALFCTB = "addLiquidityFromCustodiesToBalances";
string constant ALFBTB = "addLiquidityFromBalancesToBalances";
string constant RLFCTB = "removeLiquidityFromCustodyToBalances";
string constant RLFBTB = "removeLiquidityFromBalanceToBalances";

abstract contract AddLiquidityFromCustodiesToBalances is CommandBase {
    uint internal immutable addLiquidityFromCustodiesToBalancesId = commandId(ALFCTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, ALFCTB, maybeInput, addLiquidityFromCustodiesToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to add liquidity from the current `custodies` stream
    /// position, consuming the two custody blocks that make up the pair.
    /// `input` carries any optional extra request block and should be ignored
    /// when `maybeInput` is empty. Implementations validate and unpack it as
    /// needed. Implementations should advance `custodies` past the consumed
    /// pair and may append BALANCE outputs to `out` within the capacity
    /// implied by this command's configured `scaledRatio`.
    function addLiquidityFromCustodiesToBalances(
        bytes32 account,
        Cursor memory custodies,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function addLiquidityFromCustodiesToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(addLiquidityFromCustodiesToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory custodies, uint count) = Cursors.openKeyed(c.state, 0, Keys.Custody);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (custodies.i < custodies.end) {
            if (useInput) {
                input = Cursors.openFrom(c.request, input.next);
            }
            addLiquidityFromCustodiesToBalances(c.account, custodies, input, writer);
        }

        return writer.finish();
    }
}

abstract contract RemoveLiquidityFromCustodyToBalances is CommandBase {
    uint internal immutable removeLiquidityFromCustodyToBalancesId = commandId(RLFCTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, RLFCTB, maybeInput, removeLiquidityFromCustodyToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to remove liquidity from a custody position.
    /// `input` carries any optional extra request block and should be
    /// ignored when `maybeInput` is empty. Implementations validate and unpack
    /// it as needed, and may append BALANCE outputs to `out` within the
    /// capacity implied by this command's configured `scaledRatio`.
    function removeLiquidityFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function removeLiquidityFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(removeLiquidityFromCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory custodies, uint count) = Cursors.openKeyed(c.state, 0, Keys.Custody);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (custodies.i < custodies.end) {
            if (useInput) {
                input = Cursors.openFrom(c.request, input.next);
            }
            HostAmount memory custody = custodies.unpackCustodyValue();
            removeLiquidityFromCustodyToBalances(c.account, custody, input, writer);
        }

        return writer.finish();
    }
}

abstract contract AddLiquidityFromBalancesToBalances is CommandBase {
    uint internal immutable addLiquidityFromBalancesToBalancesId = commandId(ALFBTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, ALFBTB, maybeInput, addLiquidityFromBalancesToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to add liquidity from the current `balances` stream
    /// position, consuming the two balance blocks that make up the pair.
    /// `input` carries any optional extra request block and should be ignored
    /// when `maybeInput` is empty. Implementations validate and unpack it as
    /// needed. Implementations should advance `balances` past the consumed
    /// pair and may append BALANCE outputs to `out` within the capacity
    /// implied by this command's configured `scaledRatio`.
    function addLiquidityFromBalancesToBalances(
        bytes32 account,
        Cursor memory balances,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function addLiquidityFromBalancesToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(addLiquidityFromBalancesToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Cursors.openKeyed(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (balances.i < balances.end) {
            if (useInput) {
                input = Cursors.openFrom(c.request, input.next);
            }
            addLiquidityFromBalancesToBalances(c.account, balances, input, writer);
        }

        return writer.finish();
    }
}

abstract contract RemoveLiquidityFromBalanceToBalances is CommandBase {
    uint internal immutable removeLiquidityFromBalanceToBalancesId = commandId(RLFBTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, RLFBTB, maybeInput, removeLiquidityFromBalanceToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to remove liquidity from a balance position.
    /// `input` carries any optional extra request block and should be
    /// ignored when `maybeInput` is empty. Implementations validate and unpack
    /// it as needed, and may append BALANCE outputs to `out` within the
    /// capacity implied by this command's configured `scaledRatio`.
    function removeLiquidityFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function removeLiquidityFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(removeLiquidityFromBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Cursors.openKeyed(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (balances.i < balances.end) {
            if (useInput) {
                input = Cursors.openFrom(c.request, input.next);
            }
            AssetAmount memory balance = balances.unpackBalanceValue();
            removeLiquidityFromBalanceToBalances(c.account, balance, input, writer);
        }

        return writer.finish();
    }
}




