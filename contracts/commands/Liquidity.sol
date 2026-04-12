// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { AssetAmount, Cur, Cursors, HostAmount, Writer, Writers } from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

string constant ALFCTB = "addLiquidityFromCustodiesToBalances";
string constant ALFBTB = "addLiquidityFromBalancesToBalances";
string constant RLFCTB = "removeLiquidityFromCustodyToBalances";
string constant RLFBTB = "removeLiquidityFromBalanceToBalances";

/// @title AddLiquidityFromCustodiesToBalances
/// @notice Command that adds liquidity using paired CUSTODY state blocks and emits BALANCE outputs.
/// The hook receives the live custody cursor so it can consume a pair per iteration.
abstract contract AddLiquidityFromCustodiesToBalances is CommandBase {
    uint internal immutable addLiquidityFromCustodiesToBalancesId = commandId(ALFCTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, ALFCTB, input, addLiquidityFromCustodiesToBalancesId, State.Custodies, State.Balances);
    }

    /// @dev Override to add liquidity from the current `custodies` stream
    /// position, consuming the two custody blocks that make up the pair.
    /// `request` may be ignored by implementations that don't need it.
    /// Implementations validate and unpack it as
    /// needed. Implementations should advance `custodies` past the consumed
    /// pair and may append BALANCE outputs to `out` within the capacity
    /// implied by this command's configured `scaledRatio`.
    function addLiquidityFromCustodiesToBalances(
        bytes32 account,
        Cur memory custodies,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function addLiquidityFromCustodiesToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(addLiquidityFromCustodiesToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            addLiquidityFromCustodiesToBalances(c.account, state, request, writer);
        }

        return state.complete(writer);
    }
}

/// @title RemoveLiquidityFromCustodyToBalances
/// @notice Command that removes liquidity from a single CUSTODY state block and emits BALANCE outputs.
abstract contract RemoveLiquidityFromCustodyToBalances is CommandBase {
    uint internal immutable removeLiquidityFromCustodyToBalancesId = commandId(RLFCTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, RLFCTB, input, removeLiquidityFromCustodyToBalancesId, State.Custodies, State.Balances);
    }

    /// @dev Override to remove liquidity from a custody position.
    /// `request` may be ignored by implementations that don't need it.
    /// Implementations validate and unpack
    /// it as needed, and may append BALANCE outputs to `out` within the
    /// capacity implied by this command's configured `scaledRatio`.
    function removeLiquidityFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function removeLiquidityFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(removeLiquidityFromCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            removeLiquidityFromCustodyToBalances(c.account, custody, request, writer);
        }

        return state.complete(writer);
    }
}

/// @title AddLiquidityFromBalancesToBalances
/// @notice Command that adds liquidity using paired BALANCE state blocks and emits BALANCE outputs.
/// The hook receives the live balances cursor so it can consume a pair per iteration.
abstract contract AddLiquidityFromBalancesToBalances is CommandBase {
    uint internal immutable addLiquidityFromBalancesToBalancesId = commandId(ALFBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, ALFBTB, input, addLiquidityFromBalancesToBalancesId, State.Balances, State.Balances);
    }

    /// @dev Override to add liquidity from the current `balances` stream
    /// position, consuming the two balance blocks that make up the pair.
    /// `request` is the live auxiliary request cursor. Implementations should
    /// advance `balances` past the consumed pair, may consume `request` as
    /// needed, and may append BALANCE outputs to `out` within the capacity
    /// implied by this command's configured `scaledRatio`.
    function addLiquidityFromBalancesToBalances(
        bytes32 account,
        Cur memory balances,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function addLiquidityFromBalancesToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(addLiquidityFromBalancesToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            addLiquidityFromBalancesToBalances(c.account, state, request, writer);
        }

        return state.complete(writer);
    }
}

/// @title RemoveLiquidityFromBalanceToBalances
/// @notice Command that removes liquidity from a single BALANCE state block and emits BALANCE outputs.
abstract contract RemoveLiquidityFromBalanceToBalances is CommandBase {
    uint internal immutable removeLiquidityFromBalanceToBalancesId = commandId(RLFBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, RLFBTB, input, removeLiquidityFromBalanceToBalancesId, State.Balances, State.Balances);
    }

    /// @dev Override to remove liquidity from a balance position.
    /// `request` is the live auxiliary request cursor. Implementations may
    /// consume it as needed or ignore it, and may append BALANCE outputs to
    /// `out` within the capacity implied by this command's configured
    /// `scaledRatio`.
    function removeLiquidityFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function removeLiquidityFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(removeLiquidityFromBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            removeLiquidityFromBalanceToBalances(c.account, balance, request, writer);
        }

        return state.complete(writer);
    }
}







