// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Tx, Transact} from "./Core/Transact.sol";

////////
abstract contract Settle is Transact("") {
    function settle(
        uint from,
        uint to,
        uint id,
        uint amount
    ) internal virtual returns (uint);

    function transact(
        Tx[] calldata txs,
        bytes calldata step
    ) external payable override returns (bytes32, bytes memory) {
        for (uint i = 0; i < txs.length; i++) {
            settle(txs[i].from, txs[i].to, txs[i].id, txs[i].amount);
        }
        return done();
    }
}
