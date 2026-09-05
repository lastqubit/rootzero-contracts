// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Specs} from "./Base.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that realize balances as another asset.
abstract contract RealizeHook {
    /// @notice Override to realize `amount` of `asset` as `to`.
    /// Called once per paired BALANCE state block and AMOUNT input block. A
    /// matching BALANCE of `to` is appended using the amount returned by the hook.
    /// The hook must enforce `realized >= limit`; the command does not check it.
    /// @param asset Source balance asset.
    /// @param amount Source balance amount.
    /// @param to Asset in which to realize the balance.
    /// @param limit Minimum acceptable output amount in `to` units; zero is unbounded.
    /// @return realized Actual realized amount after fees or other adjustments.
    function realize(
        bytes32 asset,
        uint amount,
        bytes32 to,
        uint limit
    ) internal virtual returns (uint realized);
}

/// @notice Hook implemented by hosts that realize debts as another liability.
abstract contract RealizeDebtHook {
    /// @notice Override to realize `debt` of `liability` as `to`.
    /// @dev Returning successfully asserts that the entire source obligation was
    /// transformed and `realized` represents its complete replacement in `to`.
    /// No source debt remainder is emitted. Revert if the whole obligation cannot
    /// be transformed; fees, rounding, or partial fulfillment must not silently
    /// discard debt. Source and destination quantities may use different units,
    /// so their numeric amounts need not be equal or ordered.
    /// The hook must enforce `realized <= limit`; the command does not check it.
    /// @param liability Source liability identifier.
    /// @param debt Source debt amount.
    /// @param to Liability in which to realize the debt.
    /// @param limit Maximum acceptable replacement debt in `to` units; max uint is unbounded.
    /// @return realized Complete replacement debt denominated in `to`.
    function realizeDebt(
        bytes32 liability,
        uint debt,
        bytes32 to,
        uint limit
    ) internal virtual returns (uint realized);
}

/// @title Realize
/// @notice Command that realizes BALANCE state as requested output assets.
/// Each BALANCE state block is paired with one AMOUNT input block containing
/// the destination asset and minimum output amount. The bound is inclusive.
abstract contract Realize is CommandBase, RealizeHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("realize", Specs.Balance, Specs.Amount, Specs.Balance, 0);
        action(id, Actions.Realize);
    }

    /// @notice Realize BALANCE state blocks subject to their paired AMOUNT limits.
    /// @param context Command context carrying paired BALANCE state and AMOUNT input streams.
    /// @return BALANCE blocks containing the requested assets and realized amounts.
    /// @return Zero native budget credit.
    function realize(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance();
            (bytes32 to, uint limit) = exec.unpackAmount();
            amount = realize(asset, amount, to, limit);
            exec.outputBalance(to, amount);
        }

        return exec.close();
    }
}

/// @title RealizeDebt
/// @notice Command that realizes DEBT state as requested output liabilities.
/// Each DEBT state block is paired with one AMOUNT input block containing
/// the destination liability and maximum replacement debt. The bound is inclusive.
abstract contract RealizeDebt is CommandBase, RealizeDebtHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("realizeDebt", Specs.Debt, Specs.Amount, Specs.Debt, 0);
        action(id, Actions.Realize);
    }

    /// @notice Realize DEBT state blocks subject to their paired AMOUNT limits.
    /// @param context Command context carrying paired DEBT state and AMOUNT input streams.
    /// @return DEBT blocks containing the requested liabilities and realized amounts.
    /// @return Zero native budget credit.
    function realizeDebt(bytes calldata context) external onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);

        while (exec.more()) {
            (bytes32 liability, uint debt) = exec.unpackDebt();
            (bytes32 to, uint limit) = exec.unpackAmount();
            debt = realizeDebt(liability, debt, to, limit);
            exec.outputDebt(to, debt);
        }

        return exec.close();
    }
}

/// @title RealizePosition
/// @notice Command that realizes POSITION state as requested asset-liability pairs.
/// Each POSITION consumes two AMOUNT inputs: destination asset and minimum output,
/// then destination liability and maximum debt. The primitive hooks enforce the
/// limits and their results are combined into the output position.
abstract contract RealizePosition is CommandBase, RealizeHook, RealizeDebtHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("realizePosition", Specs.Position, Specs.group(Specs.Amount, 2), Specs.Position, 0);
        action(id, Actions.Realize);
    }

    /// @notice Realize POSITION state blocks as their paired requested shapes.
    /// @param context Command context carrying POSITION state and two AMOUNT inputs per position.
    /// @return POSITION blocks produced by the balance and debt realization hooks.
    /// @return Zero native budget credit.
    function realizePosition(bytes calldata context) external onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);

        while (exec.more()) {
            (bytes32 asset, uint amount, bytes32 liability, uint debt) = exec.unpackPosition();
            (bytes32 to, uint limit) = exec.unpackAmount();
            amount = realize(asset, amount, to, limit);
            asset = to;
            (to, limit) = exec.unpackAmount();
            debt = realizeDebt(liability, debt, to, limit);
            liability = to;
            exec.outputPosition(asset, amount, liability, debt);
        }

        return exec.close();
    }
}
