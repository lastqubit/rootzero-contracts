// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {SETUP, OPERATE, PROCESS, ADMIN} from "../Commands/Base.sol";
import {SELECTOR as ADD} from "../Commands/Core/Setup/Add.sol";
import {SELECTOR as ALLOW} from "../Commands/Core/Setup/Allow.sol";
import {SELECTOR as AUTHORIZE} from "../Commands/Core/Admin/Authorize.sol";
import {SELECTOR as CREATE} from "../Commands/Core/Setup/Create.sol";
import {SELECTOR as DENY} from "../Commands/Core/Setup/Deny.sol";
import {SELECTOR as INITIATE} from "../Commands/Core/Setup/Initiate.sol";
import {SELECTOR as RELOCATE} from "../Commands/Core/Admin/Relocate.sol";
import {SELECTOR as REMOVE} from "../Commands/Core/Setup/Remove.sol";
import {SELECTOR as SET} from "../Commands/Core/Setup/Set.sol";
import {SELECTOR as TRANSFER} from "../Commands/Core/Setup/Transfer.sol";
import {SELECTOR as UNAUTHORIZE} from "../Commands/Core/Admin/Unauthorize.sol";
import {SELECTOR as UPDATE} from "../Commands/Core/Setup/Update.sol";
import {SELECTOR as RELAY} from "../Commands/Core/Setup/Relay.sol";
import {SELECTOR as SINK} from "../Commands/Core/Operate/Sink.sol";
import {SELECTOR as TRANSFORM} from "../Commands/Core/Operate/Transform.sol";

function isSetup(bytes4 s) pure returns (bool) {
    return
        s == SETUP ||
        s == ADD ||
        s == ALLOW ||
        s == CREATE ||
        s == DENY ||
        s == INITIATE ||
        s == RELAY ||
        s == REMOVE ||
        s == SET ||
        s == TRANSFER ||
        s == UPDATE;
}

function isAdmin(bytes4 s) pure returns (bool) {
    return s == ADMIN || s == AUTHORIZE || s == UNAUTHORIZE || s == RELOCATE || isSetup(s);
}

function isOperate(bytes4 s) pure returns (bool) {
    return s == OPERATE || s == SINK || s == TRANSFORM;
}

function isProcess(bytes4 s) pure returns (bool) {
    return s == PROCESS;
}

function isMatch(bytes4 head, bytes4 step) pure returns (bool) {
    return head == step || (head == OPERATE && isOperate(step)) || (head == SETUP && isSetup(step));
}

function ensureNext(bytes4 head) pure {
    if (!isOperate(head)) {
        revert("Head is not a operate");
    }
}

function ensureMatch(bytes4 head, bytes4 step) pure {
    if (!isMatch(head, step)) {
        revert("Head does not match step");
    }
}
