// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "./Base.sol";
import { Cursors, Cur, Writers, Writer } from "../Cursors.sol";
using Cursors for Cur;
using Writers for Writer;

string constant NAME = "mintToBalances";

/// @title MintToBalances
/// @notice Command that mints new BALANCE outputs from a request stream.
/// The output-to-input ratio is set at construction via `scaledRatio`.
/// The hook receives both the request cursor and output writer directly to allow
/// flexible parsing patterns.
abstract contract MintToBalances is CommandBase {
    uint internal immutable mintToBalancesId = commandId(NAME);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, NAME, input, mintToBalancesId, State.Empty, State.Balances);
    }

    /// @dev Override to mint balances described by the current `input` stream
    /// position for `account`.
    /// Implementations should consume the request blocks they handle by
    /// advancing `input`, and may append BALANCE outputs to `out` within the
    /// capacity implied by this command's configured `scaledRatio`.
    function mintToBalances(
        bytes32 account,
        Cur memory input,
        Writer memory out
    ) internal virtual;

    function mintToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(mintToBalancesId, c.target) returns (bytes memory) {
        (Cur memory request, uint count, ) = cursor(c.request, 1);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);

        while (request.i < request.bound) {
            mintToBalances(c.account, request, writer);
        }

        return request.complete(writer);
    }
}





