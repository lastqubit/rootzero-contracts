// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Setup} from "./Core/Setup/Setup.sol";
import {getRequest, nextOperate} from "./Core/Base.sol";

string constant REQ = "debitFrom(uint use, uint min, uint max, uint bounty)";

struct DebitRequest {
    uint use;
    uint min;
    uint max;
    uint bounty;
}

// virtual fee function ??
abstract contract DebitFrom is Setup(REQ) {
    function toDebitRequest(bytes calldata step) private pure returns (DebitRequest memory i) {
        (i.use, i.min, i.max, i.bounty) = abi.decode(getRequest(step), (uint, uint, uint, uint));
    }

    //function collectBounty(uint account, uint id, uint bounty) internal virtual;

    function debitFrom(uint account, uint id, uint min, uint max) internal virtual returns (uint) {}

    function debitFrom(uint account, bytes calldata step) internal returns (bytes4, bytes memory) {
        DebitRequest memory q = toDebitRequest(step);
        uint amount = debitFrom(account, q.use, q.min, q.max);
        uint out; // = collectBounty(q.use, q.bounty, amount);
        return nextOperate(account, q.use, out);
    }

    function debitFrom(bytes memory args, bytes calldata step) internal returns (bytes4, bytes memory) {
        return debitFrom(abi.decode(args, (uint)), step); ////
    }

    function setup(
        uint account,
        bytes calldata step
    ) external payable override onlyTrusted returns (bytes4, bytes memory) {
        return debitFrom(account, step);
    }
}
