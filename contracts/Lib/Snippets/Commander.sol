// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {SETUP, OPERATE, PROCESS, ADMIN} from "../Commands/Base.sol";
import {SELECTOR as ACT} from "../Commands/Core/Act.sol";
import {SELECTOR as ADD} from "../Commands/Core/Add.sol";
import {SELECTOR as ALLOW} from "../Commands/Core/Allow.sol";
import {SELECTOR as AUTHORIZE} from "../Commands/Core/Authorize.sol";
import {SELECTOR as CREATE} from "../Commands/Core/Create.sol";
import {SELECTOR as DENY} from "../Commands/Core/Deny.sol";
import {SELECTOR as INITIATE} from "../Commands/Core/Initiate.sol";
import {SELECTOR as RELOCATE} from "../Commands/Core/Relocate.sol";
import {SELECTOR as REMOVE} from "../Commands/Core/Remove.sol";
import {SELECTOR as SET} from "../Commands/Core/Set.sol";
import {SELECTOR as TRANSFER} from "../Commands/Core/Transfer.sol";
import {SELECTOR as UNAUTHORIZE} from "../Commands/Core/Unauthorize.sol";
import {SELECTOR as UPDATE} from "../Commands/Core/Update.sol";
import {SELECTOR as RELAY} from "../Commands/Core/Relay.sol";
import {SELECTOR as RESOLVE} from "../Commands/Core/Resolve.sol";
import {SELECTOR as TRANSFORM} from "../Commands/Core/Transform.sol";
import {SELECTOR as UTILIZE} from "../Commands/Core/Utilize.sol";

function isSetup(bytes4 s) pure returns (bool) {
    return
        s == SETUP ||
        s == ACT ||
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
    return s == OPERATE || s == RESOLVE || s == TRANSFORM || s == UTILIZE;
}

function isProcess(bytes4 s) pure returns (bool) {
    return s == PROCESS;
}

function isMatch(bytes4 head, bytes4 step) pure returns (bool) {
    return head == step || (head == OPERATE && isOperate(step)) || (head == SETUP && isSetup(step));
}

function ensureNext(bytes4 head) pure {
    if (!isOperate(head)) {
        revert("Head is not a next");
    }
}

function ensureMatch(bytes4 head, bytes4 step) pure {
    if (!isMatch(head, step)) {
        revert("Head does not match step");
    }
}
