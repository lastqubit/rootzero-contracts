// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Node} from "../Lib/Node.sol";
import {Endpoints} from "./Endpoints.sol";
import {resolveAmount} from "../Lib/Utils.sol";

contract Faucet is Node, Endpoints {
    uint constant balance = 500; // **18 ??

    constructor(address rush, address discovery) Node(rush, discovery, "faucet") {}

    function debitFrom(uint account, uint id, uint min, uint max) internal override returns (uint) {
        uint amount = resolveAmount(balance, min, max);
        uint total = balance - amount;
        emit Balance(account, initiateId, id, total, amount);
        return amount;
    }

    function creditTo(uint account, uint id, uint amount) internal override returns (uint) {
        uint total = balance + amount;
        emit Balance(account, initiateId, id, total, amount);
        return amount;
    }
}
