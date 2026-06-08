// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, Keys} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {HostAmount, Cursors, Cur, Schemas, Writer, Writers} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";
using Cursors for Cur;
using Writers for Writer;

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
/// @notice Command that provisions assets to peer hosts from ALLOCATION request blocks.
/// Each request block supplies the target host plus an asset amount; the output is a CUSTODY state stream.
abstract contract Provision is CommandBase, ProvisionHook {
    uint internal immutable provisionId = commandId(this.provision.selector);

    constructor() {
        emit Command(host, provisionId, "1:0:1", Schemas.Allocation, Keys.Empty, Keys.Custody, false, false);
        emit Labeled(provisionId, bytes32(0), "provision");
    }

    /// @notice Provision ALLOCATION request blocks and output matching CUSTODY state blocks.
    /// @param c Command context; `c.request` must contain ALLOCATION blocks.
    /// @return CUSTODY block stream matching the provisioned allocations.
    function provision(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        (Cur memory request, uint groups, ) = Cursors.init(c.request, 0, 1);
        Writer memory writer = Writers.allocCustodies(groups);

        while (request.i < request.len) {
            HostAmount memory allocation = request.unpackAllocationValue();
            provision(c.account, allocation);
            writer.appendCustody(allocation);
        }

        request.complete();
        return writer.finish();
    }
}

/// @title ProvisionPayable
/// @notice Command that provisions assets to peer hosts from ALLOCATION request blocks.
/// Each request block supplies the target host plus an asset amount; the output is a CUSTODY state stream.
/// The hook receives a mutable native-value budget drawn from `msg.value`.
abstract contract ProvisionPayable is CommandBase, Payable, ProvisionPayableHook {
    uint internal immutable provisionPayableId = commandId(this.provisionPayable.selector);

    constructor() {
        emit Command(host, provisionPayableId, "1:0:1", Schemas.Allocation, Keys.Empty, Keys.Custody, false, true);
        emit Labeled(provisionPayableId, bytes32(0), "provisionPayable");
    }

    /// @notice Provision ALLOCATION request blocks with access to a mutable native-value budget.
    /// @param c Command context; `c.request` must contain ALLOCATION blocks.
    /// @return CUSTODY block stream matching the provisioned allocations.
    function provisionPayable(
        CommandContext calldata c
    ) external payable onlyCommand returns (bytes memory) {
        (Cur memory request, uint groups, ) = Cursors.init(c.request, 0, 1);
        Writer memory writer = Writers.allocCustodies(groups);
        Budget memory budget = valueBudget();

        while (request.i < request.len) {
            HostAmount memory allocation = request.unpackAllocationValue();
            provision(c.account, allocation, budget);
            writer.appendCustody(allocation);
        }

        settleValue(c.account, budget);
        request.complete();
        return writer.finish();
    }
}

