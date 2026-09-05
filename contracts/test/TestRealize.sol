// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Realize, RealizeDebt, RealizePosition} from "../commands/Realize.sol";
import {Runtime} from "../core/Runtime.sol";

/// @dev Stateful hooks let tests observe transaction rollback and failure order.
contract TestRealize is Realize, RealizeDebt, RealizePosition {
    error AssetFailure(uint assetCalls, uint debtCalls);
    error DebtFailure(uint assetCalls, uint debtCalls);
    error AmountBelowLimit(uint realized, uint limit);
    error DebtAboveLimit(uint realized, uint limit);

    uint public assetCalls;
    uint public debtCalls;
    uint public realizedAssets;
    uint public realizedDebts;
    uint private failAssetAt;
    uint private failDebtAt;
    bool private enforceLimits = true;

    constructor() Runtime(0) {}

    function setEnforceLimits(bool enabled) external {
        enforceLimits = enabled;
    }

    function failAt(uint assetCall, uint debtCall) external {
        failAssetAt = assetCall;
        failDebtAt = debtCall;
    }

    function enforceCaller(address caller) internal pure override returns (address) {
        return caller;
    }

    function realize(bytes32, uint amount, bytes32, uint limit) internal override returns (uint) {
        ++assetCalls;
        realizedAssets += amount;
        if (assetCalls == failAssetAt) revert AssetFailure(assetCalls, debtCalls);
        if (enforceLimits && amount < limit) revert AmountBelowLimit(amount, limit);
        return amount;
    }

    function realizeDebt(bytes32, uint debt, bytes32, uint limit) internal override returns (uint) {
        ++debtCalls;
        realizedDebts += debt;
        if (debtCalls == failDebtAt) revert DebtFailure(assetCalls, debtCalls);
        if (enforceLimits && debt > limit) revert DebtAboveLimit(debt, limit);
        return debt;
    }
}
