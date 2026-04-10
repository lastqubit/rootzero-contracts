// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { Cursors, Cur, Writers, Writer } from "../Cursors.sol";

string constant NAME = "reclaimToBalances";

using Cursors for Cur;
using Writers for Writer;

abstract contract ReclaimToBalances is CommandBase {
    uint internal immutable reclaimToBalancesId = commandId(NAME);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, NAME, input, reclaimToBalancesId, Channels.Setup, Channels.Balances);
    }

    /// @dev Override to reclaim balances described by the current `input`
    /// stream position.
    /// Implementations validate and unpack as needed, should advance `input`
    /// past the consumed request blocks, and may append BALANCE outputs to
    /// `out` within the capacity implied by this command's configured
    /// `scaledRatio`.
    function reclaimToBalances(
        bytes32 account,
        Cur memory input,
        Writer memory out
    ) internal virtual;

    function reclaimToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(reclaimToBalancesId, c.target) returns (bytes memory) {
        (Cur memory request, uint count) = cursor(c.request, 1);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);

        while (request.i < request.bound) {
            reclaimToBalances(c.account, request, writer);
        }

        return request.complete(writer);
    }
}





