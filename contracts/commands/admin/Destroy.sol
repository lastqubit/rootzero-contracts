// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";

string constant NAME = "destroy";

using Cursors for Cur;

abstract contract Destroy is CommandBase {
    uint internal immutable destroyId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, destroyId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to run host teardown or destruction logic using the
    /// decoded input.
    function destroy(Cur memory input) internal virtual;

    function destroy(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(destroyId, c.target) returns (bytes memory) {
        Cur memory input = cursor(c.request);
        destroy(input);
        return "";
    }
}






