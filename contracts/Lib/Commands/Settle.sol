// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Tx, Transact} from "./Core/Transact/Transact.sol";
import {done} from "./Core/Base.sol";

string constant REQ = "settle()";

abstract contract Settle is Transact(REQ) {
    function settle(uint from, uint to, uint id, uint amount) internal virtual returns (uint);

    function settle(bytes memory args, bytes calldata step) internal returns (bytes4, bytes memory) {}

    function transact(
        uint,
        Tx[] calldata txs,
        bytes calldata
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        for (uint i = 0; i < txs.length; i++) {
            settle(txs[i].from, txs[i].to, txs[i].id, txs[i].amount);
        }
        return done();
    }
}
