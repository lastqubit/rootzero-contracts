// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Initiate} from "./Core/Initiate.sol";

string constant REQ = "debitFrom(uint use, uint min, uint max, uint fee)";

struct DebitRequest {
    uint use;
    uint min;
    uint max;
    uint fee;
}

abstract contract DebitFrom is Initiate(REQ) {
    function toDebitRequest(
        bytes calldata step
    ) public pure returns (DebitRequest memory q) {
        return abi.decode(step[64:], (DebitRequest));
    }

    // virtual fee function ??

    function debitFrom(
        uint account,
        uint id,
        uint min,
        uint max,
        uint fee
    ) internal virtual returns (uint) {}

    function debitFrom(
        uint account,
        bytes calldata step
    ) internal returns (bytes32, bytes memory) {
        ensureValidStage(initiateId, step);
        DebitRequest memory q = toDebitRequest(step);
        uint amount = debitFrom(account, q.use, q.min, q.max, q.fee);
        return next(account, q.use, amount);
    }

    function initiate(
        uint account,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes32, bytes memory) {
        return debitFrom(account, step);
    }
}
