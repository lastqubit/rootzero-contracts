// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {RecoverPayable} from "../commands/Recover.sol";
import {Host} from "../core/Host.sol";
import {Portal} from "../core/Portal.sol";
import {UndeliveredEvent} from "../events/Undelivered.sol";

contract TestPortalRecoverHost is Host, Portal, RecoverPayable, UndeliveredEvent {
    constructor(address rootzero) Host(rootzero) {}

    function testForward(uint handler, bytes32 key, bytes calldata message, uint128 value) external payable {
        bytes32 miss = forward(handler, key, message, value);
        if (miss != bytes32(0)) emit Undelivered(host, key, miss);
    }

    function getRecoverPayableId() external view returns (uint) {
        return recoverPayableId;
    }

    function getAdminAccount() external view returns (bytes32) {
        return admin;
    }

    function recover(uint handler, bytes32 key, bytes calldata witness, uint128 value) internal override {
        retry(handler, key, witness, value);
    }
}
