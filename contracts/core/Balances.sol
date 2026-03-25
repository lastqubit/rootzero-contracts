// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {BalanceEvent} from "../events/Balance.sol";

abstract contract Balances is BalanceEvent {
    mapping(bytes32 account => mapping(bytes32 assetRef => uint amount))
        internal balances;
}
