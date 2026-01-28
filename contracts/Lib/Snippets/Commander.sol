// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {ADMIN, SETUP, OPERATE, TRANSACT, PROCESS} from "../Commands/Core/Base.sol";

import {AUTHORIZE} from "../Commands/Core/Admin/Authorize.sol";
import {UNAUTHORIZE} from "../Commands/Core/Admin/Unauthorize.sol";
import {RELOCATE} from "../Commands/Core/Admin/Relocate.sol";

import {SELECTOR as ADD} from "../Commands/Core/Setup/Add.sol";
import {SELECTOR as ALLOW} from "../Commands/Core/Setup/Allow.sol";
import {SELECTOR as CREATE} from "../Commands/Core/Setup/Create.sol";
import {SELECTOR as DENY} from "../Commands/Core/Setup/Deny.sol";
import {SELECTOR as REMOVE} from "../Commands/Core/Setup/Remove.sol";
import {SELECTOR as SET} from "../Commands/Core/Setup/Set.sol";
import {SELECTOR as TRANSFER} from "../Commands/Core/Setup/Transfer.sol";
import {SELECTOR as UPDATE} from "../Commands/Core/Setup/Update.sol";

import {OPERATE} from "../Commands/Core/Operate/Operate.sol";
import {RELAY} from "../Commands/Core/Operate/Relay.sol";
import {RESOLVE} from "../Commands/Core/Operate/Resolve.sol";
import {TRANSFORM} from "../Commands/Core/Operate/Transform.sol";

function isSetup(bytes4 s) pure returns (bool) {
    return
        s == SETUP ||
        s == ADD ||
        s == ALLOW ||
        s == CREATE ||
        s == DENY ||
        s == REMOVE ||
        s == SET ||
        s == TRANSFER ||
        s == UPDATE;
}

function isAdmin(bytes4 s) pure returns (bool) {
    return s == ADMIN || s == AUTHORIZE || s == UNAUTHORIZE || s == RELOCATE || isSetup(s);
}

function isOperate(bytes4 s) pure returns (bool) {
    return s == OPERATE || s == RELAY || s == RESOLVE || s == TRANSFORM;
}

function isTransact(bytes4 s) pure returns (bool) {
    return s == TRANSACT;
}

function isProcess(bytes4 s) pure returns (bool) {
    return s == PROCESS;
}

function canAdvance(bytes4 head, bytes4 next) pure returns (bool) {
    if (head == 0) return false;
    if (head == SETUP) return isSetup(next);
    if (head == OPERATE) return isOperate(next);
    if (head == TRANSACT) return isTransact(next);
    if (head == PROCESS) return isProcess(next);
    if (head == ADMIN) return isAdmin(next);
    return head == next;
}

/* function ensureOperate(bytes4 head) pure {
    if (isOperate(head) == false) {
        revert PipelineAdvanceError();
    }
}
 */
/* function ensureAdvanceable(bytes4 head, uint eid) pure returns (bytes4) {
    bytes4 next = bytes4(uint32(eid >> 160));
    if (canAdvance(head, next) == false) {
        revert PipelineAdvanceError();
    }
    return next;
} */
