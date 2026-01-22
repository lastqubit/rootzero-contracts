// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Node} from "../Lib/Node.sol";
import {Amount} from "../Lib/Utils/Amount.sol";
import {Endpoints} from "./Endpoints.sol";

contract Faucet is Node, Endpoints {
    uint constant disposable = 500; // **18 ??
    uint immutable eid = initiateId;

    constructor(
        address rush,
        address discovery
    ) Node(rush, discovery, "faucet") {}

    function debitFrom(
        uint account,
        uint id,
        uint min,
        uint max
    ) internal override returns (uint) {
        uint amount = Amount.resolve(disposable, min, max);
        uint out = amount - 0; //fee; ///////////
        uint total = disposable - amount;
        emit Balance(account, id, total, amount, eid);
        return out;
    }

    function creditTo(
        uint account,
        uint id,
        uint amount
    ) internal override returns (uint) {
        emit Balance(account, id, amount, amount, eid);
        return amount;
    }
}
