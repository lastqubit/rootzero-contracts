// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Writer, Writers} from "../Cursors.sol";
import {Forms} from "../blocks/Schema.sol";
import {QueryBase} from "./Base.sol";

using Cursors for Cur;

string constant NAME = "getPosition";

abstract contract GetPositionHook {
    /// @notice Resolve the position payload for one requested position.
    /// Concrete implementations must append exactly one `RESPONSE` block whose payload
    /// length matches `positionResponseSize`.
    /// @param account Requested account identifier.
    /// @param asset Requested asset identifier.
    /// @param meta Requested asset metadata slot.
    /// @param response Destination writer for the response stream.
    function appendPosition(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        Writer memory response
    ) internal view virtual;
}

/// @title GetPosition
/// @notice Rootzero query that resolves one dynamic position response for each requested position.
/// The request is a run of `ACCOUNT_ASSET` form blocks.
/// The response returns one dynamic `RESPONSE` block per position entry, preserving request order.
abstract contract GetPosition is QueryBase, GetPositionHook {
    uint public immutable getPositionId = queryId(NAME);
    uint internal immutable positionResponseSize;

    constructor(string memory output, uint responseSize) {
        positionResponseSize = responseSize;
        emit Query(host, getPositionId, NAME, Forms.AccountAsset, output);
    }

    /// @notice Resolve positions for a run of requested `(account, asset, meta)` tuples.
    /// @dev Allocates from the configured fixed response payload length so each hook call
    ///      can append one `RESPONSE` block directly into the output stream.
    /// @param request Block-stream request consisting of `accountAsset(account, asset, meta)*`.
    /// @return Block-stream response containing one `response(bytes data)` block per position block.
    function getPosition(bytes calldata request) external view returns (bytes memory) {
        (Cur memory query, uint count, ) = cursor(request, 1);
        Writer memory response = Writers.allocBytes(count, positionResponseSize);

        while (query.i < query.bound) {
            (bytes32 account, bytes32 asset, bytes32 meta) = query.unpackAccountAsset();
            appendPosition(account, asset, meta, response);
        }

        return query.complete(response);
    }
}
