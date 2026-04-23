// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, CommandPayable, State} from "./Base.sol";
import {AssetAmount, Cursors, Cur, Schemas, Writer, Writers} from "../Cursors.sol";
import {Budget, Values} from "../utils/Value.sol";
using Cursors for Cur;
using Writers for Writer;

string constant PROVISION = "provision";
string constant PP = "provisionPayable";
string constant PFB = "provisionFromBalance";

/// @notice Shared provision hook used by both `Provision` and `ProvisionFromBalance`.
abstract contract ProvisionHook {
    /// @notice Override to send or provision a custody value.
    /// Called once per provisioned asset. Implementations should perform only the
    /// side effect (e.g. transfer or record); output blocks are written by the caller.
    /// @param host Destination host node ID.
    /// @param account Caller's account identifier.
    /// @param custody Asset amount to provision.
    function provision(uint host, bytes32 account, AssetAmount memory custody) internal virtual;
}

/// @notice Shared provision hook used by `ProvisionPayable`.
abstract contract ProvisionPayableHook {
    /// @notice Override to send or provision a custody value.
    /// Called once per provisioned asset. Implementations should perform only the
    /// side effect (e.g. transfer or record); output blocks are written by the caller.
    /// @param host Destination host node ID.
    /// @param account Caller's account identifier.
    /// @param custody Asset amount to provision.
    /// @param budget Mutable native-value budget drawn from `msg.value`.
    function provision(uint host, bytes32 account, AssetAmount memory custody, Budget memory budget) internal virtual;
}

/// @title Provision
/// @notice Command that provisions assets to remote hosts from HOST_ASSET_AMOUNT request blocks.
/// Each request block supplies the target host plus an asset amount; the output is a HOST_ASSET_AMOUNT state stream.
abstract contract Provision is CommandBase, ProvisionHook {
    uint internal immutable provisionId = commandId(PROVISION);

    constructor() {
        emit Command(host, PROVISION, Schemas.HostAssetAmount, provisionId, State.Empty, State.Custodies, false);
    }

    function provision(CommandContext calldata c) external onlyCommand(c.account) returns (bytes memory) {
        (Cur memory request, uint count, ) = cursor(c.request, 1);
        Writer memory writer = Writers.allocCustodies(count);

        while (request.i < request.bound) {
            (uint host_, AssetAmount memory custody) = request.unpackHostAssetAmountValue();
            provision(host_, c.account, custody);
            writer.appendHostAssetAmount(host_, custody);
        }

        return request.complete(writer);
    }
}

/// @title ProvisionPayable
/// @notice Command that provisions assets to remote hosts from HOST_ASSET_AMOUNT request blocks.
/// Each request block supplies the target host plus an asset amount; the output is a HOST_ASSET_AMOUNT state stream.
/// The hook receives a mutable native-value budget drawn from `msg.value`.
abstract contract ProvisionPayable is CommandPayable, ProvisionPayableHook {
    uint internal immutable provisionPayableId = commandId(PP);

    constructor() {
        emit Command(host, PP, Schemas.HostAssetAmount, provisionPayableId, State.Empty, State.Custodies, true);
    }

    function provisionPayable(
        CommandContext calldata c
    ) external payable onlyCommand(c.account) returns (bytes memory) {
        (Cur memory request, uint count, ) = cursor(c.request, 1);
        Writer memory writer = Writers.allocCustodies(count);
        Budget memory budget = Values.fromMsg();

        while (request.i < request.bound) {
            (uint host_, AssetAmount memory custody) = request.unpackHostAssetAmountValue();
            provision(host_, c.account, custody, budget);
            writer.appendHostAssetAmount(host_, custody);
        }

        settleValue(c.account, budget);
        return request.complete(writer);
    }
}

/// @title ProvisionFromBalance
/// @notice Command that converts BALANCE state into HOST_ASSET_AMOUNT state for a destination host.
/// The destination node is read from an optional NODE trailing block; reverts if absent.
abstract contract ProvisionFromBalance is CommandBase, ProvisionHook {
    uint internal immutable provisionFromBalanceId = commandId(PFB);

    constructor() {
        emit Command(host, PFB, Schemas.Node, provisionFromBalanceId, State.Balances, State.Custodies, false);
    }

    function provisionFromBalance(
        CommandContext calldata c
    ) external onlyCommand(c.account) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Writer memory writer = Writers.allocCustodies(stateCount);
        uint peer = Cursors.resolveNodeOrRevert(c.request, 0);

        while (state.i < state.bound) {
            AssetAmount memory custody = state.unpackBalanceValue();
            provision(peer, c.account, custody);
            writer.appendHostAssetAmount(peer, custody);
        }

        return state.complete(writer);
    }
}
