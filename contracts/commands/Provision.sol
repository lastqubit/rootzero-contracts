// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, Keys} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {HostAmount, Cursors, Cur, Writer, Writers} from "../Cursors.sol";
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
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("provision", Keys.Empty, Keys.Allocation, Keys.Custody, 0, false, false);
    }

    /// @notice Provision ALLOCATION request blocks and output matching CUSTODY state blocks.
    /// @param c Command context; `c.input` must contain ALLOCATION blocks.
    /// @return CUSTODY block stream matching the provisioned allocations.
    function provision(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        (Cur memory input, uint outputs) = openInput(c.input, descriptor);
        Writer memory output = Writers.allocCustodies(outputs);

        while (input.i < input.len) {
            HostAmount memory allocation = input.unpackAllocationValue();
            provision(c.account, allocation);
            output.appendCustody(allocation);
        }

        return output.finish();
    }
}

/// @title ProvisionPayable
/// @notice Command that provisions assets to peer hosts from ALLOCATION request blocks.
/// Each request block supplies the target host plus an asset amount; the output is a CUSTODY state stream.
/// The hook receives a mutable native-value budget drawn from `msg.value`.
abstract contract ProvisionPayable is CommandBase, Payable, ProvisionPayableHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("provisionPayable", Keys.Empty, Keys.Allocation, Keys.Custody, 0, true, false);
    }

    /// @notice Provision ALLOCATION request blocks with access to a mutable native-value budget.
    /// @param c Command context; `c.input` must contain ALLOCATION blocks.
    /// @return CUSTODY block stream matching the provisioned allocations.
    function provisionPayable(
        CommandContext calldata c
    ) external payable onlyCommand returns (bytes memory) {
        (Cur memory input, uint outputs) = openInput(c.input, descriptor);
        Writer memory output = Writers.allocCustodies(outputs);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            HostAmount memory allocation = input.unpackAllocationValue();
            provision(c.account, allocation, budget);
            output.appendCustody(allocation);
        }

        closeValue(c.account, budget);
        return output.finish();
    }
}

