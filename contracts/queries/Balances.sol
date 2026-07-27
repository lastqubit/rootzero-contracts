// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Keys, Specs} from "../Cursors.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {QueryBase} from "./Base.sol";

using Executions for Execution;

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
/// The request is a run of `ACCOUNT_ASSET` form blocks.
/// The response returns one `ACCOUNT_AMOUNT` form block per requested position, preserving request order.
abstract contract GetBalances is QueryBase, GetBalancesHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = query("getBalances", Specs.AccountAsset, Specs.AccountAmount, 0);
    }

    /// @notice Resolve balances for a run of requested `(account, asset)` tuples.
    /// @param request Block-stream request consisting of `accountAsset(account, asset)*`.
    /// @return Block-stream response containing one `accountAmount(account, asset, amount)` block per request block.
    function getBalances(bytes calldata request) external view returns (bytes memory) {
        Execution memory exec = openInput(request, descriptor, 0);

        while (exec.more()) {
            (bytes32 account, bytes32 asset) = exec.unpackAccountAsset(Lanes.Input);
            uint amount = getBalance(account, asset);
            exec.outputAccountAmount(account, asset, amount);
        }

        return end(exec);
    }
}
