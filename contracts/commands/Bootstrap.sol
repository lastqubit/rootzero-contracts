// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Specs} from "./Base.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Sizes} from "../codec/Specs.sol";
import {Cursors} from "../utils/Cursors.sol";
import {DebitAccountHook} from "../core/Settlement.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that source bootstrap pipeline budget.
abstract contract BootstrapBudgetHook {
    /// @notice Source native-value budget for `account` during bootstrap.
    /// Called once per BOOTSTRAP input block.
    /// @dev Implementations must revert unless the contribution can be made available.
    /// A zero amount is valid and may return immediately without changing state.
    /// @param account Account funding the pipeline.
    /// @param amount Native value added to the pipeline budget.
    function bootstrapBudget(bytes32 account, uint amount) internal virtual;
}

/// @title Bootstrap
/// @notice Command that atomically starts a pipeline with BALANCE state and native-value budget.
abstract contract Bootstrap is CommandBase, DebitAccountHook, BootstrapBudgetHook {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("bootstrap", Specs.Empty, Specs.Bootstrap, Specs.Balance, 0);
    }

    /// @notice Return the registered BOOTSTRAP command ID.
    function bootstrapId() internal view returns (uint) {
        return id;
    }

    /// @notice Source initial balances and budget contributions for a pipeline.
    /// @param context Command context carrying a BOOTSTRAP input stream.
    /// @return output One BALANCE block per BOOTSTRAP input.
    /// @return credit Sum of trusted native value contributed by every input.
    function bootstrap(
        bytes calldata context
    ) external onlyCommand returns (bytes memory output, uint credit) {
        Execution memory exec = openCommand(context, descriptor);

        while (exec.more()) {
            (bytes32 asset, uint amount, uint budget) = exec.unpackBootstrap();
            debitAccount(exec.account, asset, amount);
            bootstrapBudget(exec.account, budget);
            exec.outputBalance(asset, amount);
            credit += budget;
        }

        return exec.close(credit);
    }
}

/// @title BootstrapInternal
/// @notice Extends bootstrap with optimized local pipeline dispatch.
abstract contract BootstrapInternal is Bootstrap {
    /// @notice Execute bootstrap directly against a calldata BOOTSTRAP stream.
    /// @param account Account funding the pipeline.
    /// @param state Empty pipeline state required by the command schema.
    /// @param input BOOTSTRAP block stream.
    /// @param value Native value assigned to this command; must be zero.
    /// @return output One BALANCE block per BOOTSTRAP input.
    /// @return credit Sum of the sourced budget contributions.
    function executeBootstrap(
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint128 value
    ) internal returns (bytes memory output, uint credit) {
        if (value != 0) revert ValueNotAllowed();
        if (state.length != 0) revert Executions.ZeroStride();
        if (input.length % Sizes.Bootstrap != 0) revert Blocks.InvalidBlock();

        (uint abs, uint end) = Cursors.bounds(input);
        output = new bytes(input.length / Sizes.Bootstrap * Sizes.Balance);
        uint i;

        while (abs < end) {
            (bytes32 asset, uint amount, uint budget) = Blocks.unpackBootstrap(abs);
            debitAccount(account, asset, amount);
            bootstrapBudget(account, budget);
            Blocks.writeBalance(output, i, asset, amount);
            credit += budget;
            unchecked {
                abs += Sizes.Bootstrap;
                i += Sizes.Balance;
            }
        }
    }
}
