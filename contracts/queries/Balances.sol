// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Specs} from "../Codec.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {QueryBase} from "./Base.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that expose account balance queries.
abstract contract GetBalancesHook {
    /// @notice Resolve one account's balance for one supported asset.
    /// Concrete implementations define how assets are resolved.
    /// @param account Account identifier carried by the query payload.
    /// @param asset Requested asset identifier.
    /// @return amount Current balance in the asset's native units.
    function getBalance(bytes32 account, bytes32 asset) internal view virtual returns (uint amount);
}

/// @title GetBalances
/// @notice Rootzero query that resolves balances for one or more `(account, asset)` tuples.
/// The input is a run of `ACCOUNT_ASSET` form blocks.
/// The response returns one `ACCOUNT_AMOUNT` form block per requested position, preserving input order.
abstract contract GetBalances is QueryBase, GetBalancesHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = query("getBalances", Specs.AccountAsset, Specs.AccountAmount);
    }

    /// @notice Resolve balances for a run of requested `(account, asset)` tuples.
    /// @param input Block-stream input consisting of `accountAsset(account, asset)*`.
    /// @return Block-stream response containing one `accountAmount(account, asset, amount)` block per input block.
    function getBalances(bytes calldata input) external view returns (bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            (bytes32 account, bytes32 asset) = exec.unpackAccountAsset(Lanes.Input);
            uint amount = getBalance(account, asset);
            exec.outputAccountAmount(account, asset, amount);
        }

        return close(exec);
    }
}
