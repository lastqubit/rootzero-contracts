// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, SETUP, BALANCES, CUSTODIES} from "./Base.sol";
import {AssetAmount, HostAmount, CUSTODY_KEY, Blocks, BlockRef, Data, DataRef, Writers, Writer} from "../Blocks.sol";

bytes32 constant STAKECUSTODYTOBALANCE = "stakeCustodyToBalance";
bytes32 constant STAKECUSTODYTOPOSITION = "stakeCustodyToPosition";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

abstract contract StakeCustodyToBalance is CommandBase {
    uint internal immutable stakeCustodyToBalanceId = commandId(STAKECUSTODYTOBALANCE);

    constructor(string memory route) {
        emit Command(host, STAKECUSTODYTOBALANCE, route, stakeCustodyToBalanceId, CUSTODIES, BALANCES);
    }

    function stakeCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory);

    function stakeCustodyToBalance(CommandContext calldata c) external payable onlyCommand(stakeCustodyToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, CUSTODY_KEY);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.custodyFrom(c.state, i);
            HostAmount memory custody = ref.toCustodyValue(c.state);
            AssetAmount memory out = stakeCustodyToBalance(c.account, custody, route);
            if (out.amount > 0) writer.appendBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}

abstract contract StakeCustodyToPosition is CommandBase {
    uint internal immutable stakeCustodyToPositionId = commandId(STAKECUSTODYTOPOSITION);

    constructor(string memory route) {
        emit Command(host, STAKECUSTODYTOPOSITION, route, stakeCustodyToPositionId, CUSTODIES, SETUP);
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
