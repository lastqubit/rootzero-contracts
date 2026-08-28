// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Specs} from "./Base.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Sizes} from "../codec/Specs.sol";
import {Cursors} from "../utils/Cursors.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";
import {UnexpectedState} from "../utils/Errors.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that withdraw native assets from accounts.
abstract contract CashoutHook {
    /// @notice Withdraw an exact native-asset amount from `account`.
    /// Called once per CASHOUT input block.
    /// @dev Implementations must revert when the requested amount cannot be withdrawn.
    /// @param account Account whose native asset is withdrawn.
    /// @param amount Native-asset amount to withdraw.
    function cashout(bytes32 account, uint amount) internal virtual;
}

/// @title Cashout
/// @notice Command that withdraws requested native-asset amounts from its account.
abstract contract Cashout is CommandBase, CashoutHook, Action {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("cashout", Specs.Empty, Specs.Cashout, Specs.Empty, 0);
        action(id, Actions.Cashout);
    }

    /// @notice Return the registered CASHOUT command ID.
    function cashoutId() internal view returns (uint) {
        return id;
    }

    /// @notice Withdraw native-asset amounts from the command account.
    /// @param context Command context carrying a CASHOUT input stream.
    /// @return output Empty output state.
    /// @return credit Zero native budget credit.
    function cashout(
        bytes calldata context
    ) external onlyCommand returns (bytes memory output, uint credit) {
        Execution memory exec = openCommand(context, descriptor);

        while (exec.more()) {
            cashout(exec.account, exec.unpackCashout());
        }

        return exec.close();
    }
}

/// @title CashoutInternal
/// @notice Extends cashout with optimized local pipeline dispatch.
abstract contract CashoutInternal is Cashout {
    /// @notice Execute cashout directly against a calldata CASHOUT stream.
    /// @param account Account whose native asset is withdrawn.
    /// @param state Empty pipeline state required by the command schema.
    /// @param input CASHOUT block stream.
    /// @param value Native value assigned to this command; must be zero.
    /// @return output Empty output state.
    /// @return credit Zero native budget credit.
    function executeCashout(
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint128 value
    ) internal returns (bytes memory, uint) {
        if (value != 0) revert ValueNotAllowed();
        if (state.length != 0) revert UnexpectedState();
        if (input.length % Sizes.Cashout != 0) revert Blocks.InvalidBlock();

        (uint abs, uint end) = Cursors.bounds(input);
        while (abs < end) {
            cashout(account, Blocks.unpackCashout(abs));
            unchecked {
                abs += Sizes.Cashout;
            }
        }
        return ("", 0);
    }
}
