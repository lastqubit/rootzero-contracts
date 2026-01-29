// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Resolve} from "./Core/Operate/Resolve.sol";
import {OpInput, decodeOperate} from "./Core/Operate/Operate.sol";
import {done, getRequest} from "./Core/Base.sol";
import {ensureAmount, ensureAccount} from "../Utils.sol";

string constant REQ = "creditTo(uint to)";

abstract contract CreditTo is Resolve(REQ) {
    function resolveTo(uint account, bytes calldata req) private pure returns (uint) {
        if (req.length == 0) return account;
        return ensureAccount(abi.decode(req, (uint)));
    }

    function creditTo(uint account, uint id, uint amount) internal virtual returns (uint);

    function creditTo(uint account, uint id, uint amount, bytes calldata step) internal returns (bytes4, bytes memory) {
        uint to = resolveTo(account, getRequest(step));
        ensureAmount(creditTo(to, id, amount));
        return done();
    }

    // ensure head is operate ??
    function creditTo(bytes4 head, bytes memory args) internal returns (bytes4, bytes memory) {
        OpInput memory i = decodeOperate(args);
        ensureAmount(creditTo(i.account, i.id, i.amount));
        return done();
    }

    function creditTo(bytes memory args, bytes calldata step) internal returns (bytes4, bytes memory) {
        OpInput memory i = decodeOperate(args);
        return creditTo(i.account, i.id, i.amount, step);
    }

    function resolve(
        uint account,
        uint id,
        uint amount,
        bytes calldata,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return creditTo(account, id, amount, step);
    }
}
