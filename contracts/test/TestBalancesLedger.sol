// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Balances} from "../core/Balances.sol";

contract TestBalancesLedger is Balances {
    function creditToAccount(bytes32 account, bytes32 asset, uint amount) external returns (uint) {
        return creditTo(account, asset, amount);
    }

    function debitFromAccount(bytes32 account, bytes32 asset, uint amount) external returns (uint) {
        return debitFrom(account, asset, amount);
    }

    function accountBalance(bytes32 account, bytes32 asset) external view returns (uint) {
        return balances[account][asset];
    }
}
