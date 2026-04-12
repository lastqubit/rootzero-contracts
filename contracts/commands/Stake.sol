// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { AssetAmount, HostAmount, Cur, Cursors, Writer, Writers } from "../Cursors.sol";

string constant SBTB = "stakeBalanceToBalances";
string constant SCTB = "stakeCustodyToBalances";
string constant SCTP = "stakeCustodyToPosition";

using Cursors for Cur;
using Writers for Writer;

/// @title StakeBalanceToBalances
/// @notice Command that stakes BALANCE state positions and emits BALANCE outputs.
/// The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract StakeBalanceToBalances is CommandBase {
    uint internal immutable stakeBalanceToBalancesId = commandId(SBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, SBTB, input, stakeBalanceToBalancesId, State.Balances, State.Balances);
    }

    /// @dev Override to stake a balance position and append resulting balances
    /// to `out`. `request` is the live auxiliary request cursor for this
    /// command; implementations validate and unpack it as needed and may
    /// append BALANCE outputs within the capacity implied by this command's
    /// configured `scaledRatio`.
    function stakeBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function stakeBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(stakeBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            stakeBalanceToBalances(c.account, balance, request, writer);
        }

        return state.complete(writer);
    }
}

/// @title StakeCustodyToBalances
/// @notice Command that stakes CUSTODY state positions and emits BALANCE outputs.
/// The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract StakeCustodyToBalances is CommandBase {
    uint internal immutable stakeCustodyToBalancesId = commandId(SCTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, SCTB, input, stakeCustodyToBalancesId, State.Custodies, State.Balances);
    }

    /// @dev Override to stake a custody position and append resulting balances
    /// to `out`. `request` is the live auxiliary request cursor for this
    /// command; implementations validate and unpack it as needed and may
    /// append BALANCE outputs within the capacity implied by this command's
    /// configured `scaledRatio`.
    function stakeCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function stakeCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(stakeCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            stakeCustodyToBalances(c.account, custody, request, writer);
        }

        return state.complete(writer);
    }
}

/// @title StakeCustodyToPosition
/// @notice Command that stakes CUSTODY state positions into a non-balance target
/// described by the request stream. Produces no output state.
abstract contract StakeCustodyToPosition is CommandBase {
    uint internal immutable stakeCustodyToPositionId = commandId(SCTP);

    constructor(string memory input) {
        emit Command(host, SCTP, input, stakeCustodyToPositionId, State.Custodies, State.Empty);
    }

    /// @dev Override to stake a custody position into a non-balance setup
    /// target described by `request`.
    function stakeCustodyToPosition(bytes32 account, HostAmount memory custody, Cur memory request) internal virtual;

    function stakeCustodyToPosition(
        CommandContext calldata c
    ) external payable onlyCommand(stakeCustodyToPositionId, c.target) returns (bytes memory) {
        (Cur memory state, , ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            stakeCustodyToPosition(c.account, custody, request);
        }

        state.complete();
        return "";
    }
}







