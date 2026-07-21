// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Keys, Writer, Writers} from "../Cursors.sol";
import {QueryBase} from "./Base.sol";

using Cursors for Cur;
using Writers for Writer;

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
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = query("getBalances", Keys.AccountAsset, Keys.AccountAmount, 0);
    }

    /// @notice Resolve balances for a run of requested `(account, asset)` tuples.
    /// @param request Block-stream request consisting of `accountAsset(account, asset)*`.
    /// @return Block-stream response containing one `accountAmount(account, asset, amount)` block per request block.
    function getBalances(bytes calldata request) external view returns (bytes memory) {
        (Cur memory input, uint outputs) = openInput(request, descriptor);
        Writer memory response = Writers.allocAccountAmounts(outputs);

        while (input.i < input.len) {
            (bytes32 account, bytes32 asset) = input.unpackAccountAsset();
            uint amount = getBalance(account, asset);
            response.appendAccountAmount(account, asset, amount);
        }

        return end(response);
    }
}
