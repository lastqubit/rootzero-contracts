// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Initiate} from "./Core/Initiate.sol";

string constant REQ = "debitFrom(uint use, uint min, uint max)";

struct DebitRequest {
    uint use;
    uint min;
    uint max;
}

// virtual fee function ??
abstract contract DebitFrom is Initiate(REQ) {
    function decodeDebit(bytes calldata step) private pure returns (DebitRequest memory i) {
        (i.use, i.min, i.max) = abi.decode(getRequest(step), (uint, uint, uint));
    }

    function debitFrom(uint account, uint id, uint min, uint max) internal virtual returns (uint) {}

    function debitFrom(uint account, bytes calldata step) internal returns (bytes32, bytes memory) {
        ensureValidStage(initiateId, step);
        DebitRequest memory q = decodeDebit(step);
        uint amount = debitFrom(account, q.use, q.min, q.max);
        return next(account, q.use, amount);
    }

    function initiate(
        uint account,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes32, bytes memory) {
        return debitFrom(account, step);
    }
}
