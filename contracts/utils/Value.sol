// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

struct ValueBudget {
    uint remaining;
}

error InsufficientValue();

function msgValue() view returns (ValueBudget memory) {
    return ValueBudget({remaining: msg.value});
}

function useValue(uint amount, ValueBudget memory budget) pure returns (uint) {
    if (amount > budget.remaining) revert InsufficientValue();
    budget.remaining -= amount;
    return amount;
}
