// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {SETUP, BALANCES, CUSTODIES} from "../utils/Channels.sol";
import {AssetAmount, HostAmount, BALANCE_KEY, CUSTODY_KEY, Blocks, BlockRef, Data, DataRef, Writers, Writer} from "../Blocks.sol";

string constant SBTB = "stakeBalanceToBalances";
string constant SCTB = "stakeCustodyToBalances";
string constant SCTP = "stakeCustodyToPosition";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

abstract contract StakeBalanceToBalances is CommandBase {
    uint internal immutable stakeBalanceToBalancesId = commandId(SBTB);
    uint private immutable outScale;

    constructor(string memory route, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, SBTB, route, stakeBalanceToBalancesId, BALANCES, BALANCES);
    }

    function stakeBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function stakeBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(stakeBalanceToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, BALANCE_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            stakeBalanceToBalances(c.account, balance, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}

abstract contract StakeCustodyToBalances is CommandBase {
    uint internal immutable stakeCustodyToBalancesId = commandId(SCTB);
    uint private immutable outScale;

    constructor(string memory route, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, SCTB, route, stakeCustodyToBalancesId, CUSTODIES, BALANCES);
    }

    function stakeCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function stakeCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(stakeCustodyToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, CUSTODY_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue(c.state);
            stakeCustodyToBalances(c.account, custody, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}

abstract contract StakeCustodyToPosition is CommandBase {
    uint internal immutable stakeCustodyToPositionId = commandId(SCTP);

    constructor(string memory route) {
        emit Command(host, SCTP, route, stakeCustodyToPositionId, CUSTODIES, SETUP);
    }

    function stakeCustodyToPosition(bytes32 account, HostAmount memory custody, DataRef memory rawRoute) internal virtual;

    function stakeCustodyToPosition(
        CommandContext calldata c
    ) external payable onlyCommand(stakeCustodyToPositionId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        while (i < c.state.length) {
            BlockRef memory ref = Blocks.from(c.state, i);
            if (!ref.isCustody()) break;
            HostAmount memory custody = ref.toCustodyValue(c.state);
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            stakeCustodyToPosition(c.account, custody, route);
            i = ref.end;
        }

        return done(0, i);
    }
}
