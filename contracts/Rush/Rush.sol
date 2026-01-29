// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Executor, Ownable} from "./Executor.sol";
import {Node} from "../Lib/Node.sol";
import {Discovery} from "../Lib/Snippets/Discovery.sol";
import {Validator} from "../Lib/Validation/Validator.sol";
import {ADMIN, SETUP} from "../Lib/Commands/Core/Base.sol";
import {addrOr, toAccountId, ensureNotExpired, msgValue} from "../Lib/Utils.sol";

contract Rush is Executor, Validator, Discovery {
    constructor(address owner) Node(address(0), address(0), "admin") Ownable(addrOr(owner, msg.sender)) {}

    modifier notExpired(uint192 deadline) {
        ensureNotExpired(deadline);
        _;
    }

    function getBalance(uint account, uint id) internal view override returns (uint) {
        return balances[account][id];
    }

    function validate(uint192 deadline, bytes[] calldata steps, bytes calldata signed) internal returns (address) {
        bytes32 hash = keccak256(abi.encode(steps, pipeId, deadline));
        address addr = validateRecover(hash, signed);
        useNonce(addr, deadline, 0);
        return addr;
    }

    function inject(bytes[] calldata steps) external payable override onlyOwner returns (uint) {
        return pipe(ADMIN, abi.encode(admin, ""), steps, msgValue());
    }

    function pipe(
        uint192 deadline,
        bytes[] calldata steps,
        bytes calldata signed
    ) external payable override notExpired(deadline) returns (uint) {
        address addr = signed.length == 0 ? msg.sender : validate(deadline, steps, signed);
        uint account = toAccountId(addr);
        return pipe(SETUP, abi.encode(account, ""), steps, msgValue());
    }

    function resume(
        bytes4 head,
        bytes memory args,
        bytes[] calldata steps
    ) external payable override onlyAuthorized returns (uint) {
        return pipe(head, args, steps, msgValue());
    }
}
