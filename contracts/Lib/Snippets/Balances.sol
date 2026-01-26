// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {CreditTo} from "../Commands/CreditTo.sol";
import {DebitFrom} from "../Commands/DebitFrom.sol";
import {Settle} from "../Commands/Settle.sol";
import {BalanceEvent} from "../Events/Account/Balance.sol";
import {difference, resolveAmount} from "../Utils.sol";

abstract contract Balances is DebitFrom, CreditTo, Settle, BalanceEvent {
    mapping(uint account => mapping(uint id => uint amount)) internal balances;

    function creditTo(uint account, uint id, uint amount) internal override returns (uint) {
        if (amount == 0 || account == 0) return 0;
        uint total = balances[account][id] += amount;
        emit Balance(account, initiateId, id, total, amount);
        return amount;
    }

    function debitFrom(uint account, uint id, uint amount) internal returns (uint) {
        if (amount == 0 || account == 0) return 0;
        uint total = balances[account][id] -= amount;
        emit Balance(account, initiateId, id, total, amount);
        return amount;
    }

    function debitFrom(uint account, uint id, uint min, uint max) internal override returns (uint) {
        uint amount = resolveAmount(balances[account][id], min, max);
        return debitFrom(account, id, amount);
    }

    function settle(uint from, uint to, uint id, uint amount) internal override returns (uint) {
        return difference(debitFrom(from, id, amount), creditTo(to, id, amount));
    }
}
