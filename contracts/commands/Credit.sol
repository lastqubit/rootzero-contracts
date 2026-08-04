// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Lanes, Specs} from "./Base.sol";
import {CreditAccountHook} from "../core/Settlement.sol";

using Executions for Execution;

/// @title CreditAccount
/// @notice Command that delivers BALANCE state blocks to an account via a virtual hook.
/// Use for internally recording credits that have already been settled externally.
abstract contract CreditAccount is CommandBase, CreditAccountHook {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("creditAccount", Specs.Balance, Specs.Empty, Specs.Empty, 0, false, false);
    }

    /// @notice Return the registered CREDIT_ACCOUNT command ID.
    function creditAccountId() internal view returns (uint) {
        return id;
    }

    /// @notice Credit each BALANCE block from the command state to the command account.
    /// @param state BALANCE block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function creditAccount(
        bytes32 account,
        bytes calldata state,
        bytes calldata
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openState(state, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance(Lanes.State);
            creditAccount(account, asset, amount);
        }

        return close(exec, account);
    }
}
