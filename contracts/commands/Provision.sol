// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, CommandPayable, Keys} from "./Base.sol";
import {HostAmount, Cursors, Cur, Schemas, Writer, Writers} from "../Cursors.sol";
import {Budget, Values} from "../utils/Value.sol";
using Cursors for Cur;
using Writers for Writer;

string constant PROVISION = "provision";
string constant PP = "provisionPayable";

/// @notice Shared provision hook used by `Provision`.
abstract contract ProvisionHook {
    /// @notice Override to send or provision a custody value.
    /// Called once per provisioned asset. Implementations should perform only the
    /// side effect (e.g. transfer or record); output blocks are written by the caller.
    /// @param account Caller's account identifier.
    /// @param allocation Host-scoped amount to provision.
    function provision(bytes32 account, HostAmount memory allocation) internal virtual;
}

/// @notice Shared provision hook used by `ProvisionPayable`.
abstract contract ProvisionPayableHook {
    /// @notice Override to send or provision a custody value.
    /// Called once per provisioned asset. Implementations should perform only the
    /// side effect (e.g. transfer or record); output blocks are written by the caller.
    /// @param account Caller's account identifier.
    /// @param allocation Host-scoped amount to provision.
    /// @param budget Mutable native-value budget drawn from `msg.value`.
    function provision(bytes32 account, HostAmount memory allocation, Budget memory budget) internal virtual;
}

/// @title Provision
/// @notice Command that provisions assets to remote hosts from ALLOCATION request blocks.
/// Each request block supplies the target host plus an asset amount; the output is a CUSTODY state stream.
abstract contract Provision is CommandBase, ProvisionHook {
    uint internal immutable provisionId = commandId(PROVISION);

    constructor() {
        emit Command(host, provisionId, PROVISION, Schemas.Allocation, Keys.Empty, Keys.Custody, false);
    }

    function provision(CommandContext calldata c) external onlyCommand(c.account) returns (bytes memory) {
        (Cur memory request, uint count, ) = cursor(c.request, 1);
        Writer memory writer = Writers.allocCustodies(count);

        while (request.i < request.bound) {
            HostAmount memory allocation = request.unpackAllocationValue();
            provision(c.account, allocation);
            writer.appendCustody(allocation);
        }

        return request.complete(writer);
    }
}

/// @title ProvisionPayable
/// @notice Command that provisions assets to remote hosts from ALLOCATION request blocks.
/// Each request block supplies the target host plus an asset amount; the output is a CUSTODY state stream.
/// The hook receives a mutable native-value budget drawn from `msg.value`.
abstract contract ProvisionPayable is CommandPayable, ProvisionPayableHook {
    uint internal immutable provisionPayableId = commandId(PP);

    constructor() {
        emit Command(host, provisionPayableId, PP, Schemas.Allocation, Keys.Empty, Keys.Custody, true);
    }

    function provisionPayable(
        CommandContext calldata c
    ) external payable onlyCommand(c.account) returns (bytes memory) {
        (Cur memory request, uint count, ) = cursor(c.request, 1);
        Writer memory writer = Writers.allocCustodies(count);
        Budget memory budget = Values.fromMsg();

        while (request.i < request.bound) {
            HostAmount memory allocation = request.unpackAllocationValue();
            provision(c.account, allocation, budget);
            writer.appendCustody(allocation);
        }

        settleValue(c.account, budget);
        return request.complete(writer);
    }
}

