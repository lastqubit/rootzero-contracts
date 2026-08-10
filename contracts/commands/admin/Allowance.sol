// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @notice Hook implemented by hosts that configure peer asset allowances.
abstract contract AllowanceHook {
    /// @notice Apply or revoke one host-scoped allowance.
    /// Called once per ALLOWANCE block in the input. Implementations decide
    /// how the allowance is represented, e.g. ERC-20 approval, an internal cap,
    /// or another host-specific authorization record.
    /// @param peer Host node receiving the allowed cap.
    /// @param asset Asset identifier.
    /// @param amount Allowed cap amount. A zero amount MUST revoke the allowance.
    function allowance(uint peer, bytes32 asset, uint amount) internal virtual;
}

/// @title Allowance
/// @notice Admin command that applies cross-host allowance entries via a virtual hook.
/// Each ALLOWANCE block grants or updates a host-scoped asset cap. Only callable by the admin account.
abstract contract Allowance is AdminBase, AllowanceHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("allowance", Specs.Empty, Specs.Allowance, Specs.Empty, 0, false, true);
    }

    /// @notice Apply each ALLOWANCE block in the admin input.
    /// @param input ALLOWANCE block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function allowance(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (uint peer, bytes32 asset, uint amount) = exec.unpackAllowance(Lanes.Input);
            allowance(peer, asset, amount);
        }

        return close(exec, account);
    }
}
