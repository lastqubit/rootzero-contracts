// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Resolve} from "./Core/Resolve.sol";
import {NextInput, decodeNext} from "./Base.sol";
import {ensureAmount} from "../Utils/Amount.sol";

string constant REQ = "creditTo(uint to)";

struct CreditRequest {
    uint to;
}

abstract contract CreditTo is Resolve(REQ) {
    function toCreditRequest(bytes calldata step) private pure returns (CreditRequest memory) {
        return CreditRequest(0);
        //return abi.decode(step[64:], (CreditRequest));
    }

    function resolveTo(uint account, bytes calldata) private returns (uint) {
        // CreditRequest memory q = toCreditRequest(step);
        return account;
    }

    function creditTo(uint account, uint id, uint amount) internal virtual returns (uint);

    function creditTo(
        uint account,
        uint id,
        uint amount,
        bytes calldata step
    ) internal returns (bytes32, bytes memory) {
        ensureValidStage(resolveId, step);
        uint to = resolveTo(account, step);
        ensureAmount(creditTo(to, id, amount));
        return done();
    }

    function creditTo(bytes memory body, bytes calldata step) internal returns (bytes32, bytes memory) {
        NextInput memory i = decodeNext(body);
        return creditTo(i.account, i.id, i.amount, step);
    }

    function resolve(
        uint account,
        uint id,
        uint amount,
        bytes calldata,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes32, bytes memory) {
        return creditTo(account, id, amount, step);
    }
}
