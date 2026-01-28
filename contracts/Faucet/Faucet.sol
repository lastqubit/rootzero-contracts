// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Node} from "../Lib/Node.sol";
import {Endpoints} from "./Endpoints.sol";
import {resolveAmount} from "../Lib/Utils.sol";

contract Faucet is Node, Endpoints {
    uint constant BALANCE = 1000 * (10 ** 18);
    uint immutable eid = setupId;

    constructor(address cmdr, address discovery) Node(cmdr, discovery, "faucet") {}

    function debitFrom(uint account, uint id, uint min, uint max) internal override returns (uint) {
        uint amount = resolveAmount(BALANCE, min, max);
        uint balance = BALANCE - amount;
        emit Balance(account, eid, id, balance, amount);
        return amount;
    }

    function creditTo(uint account, uint id, uint amount) internal override returns (uint) {
        uint balance = BALANCE + amount;
        emit Balance(account, eid, id, balance, amount);
        return amount;
    }
}
