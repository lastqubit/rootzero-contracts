// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Executor, Value, Ownable} from "./Executor.sol";
import {Node} from "../Lib/Node.sol";
import {Id} from "../Lib/Id.sol";
import {addrOr} from "../Lib/Utils.sol";
import {ENTRY} from "../Lib/Commands/Base.sol";

contract Rush is Executor {
    mapping(uint => bool) internal initial; /////

    constructor(
        address owner,
        address discovery
    ) Node(address(0), discovery, "admin") Ownable(addrOr(owner, msg.sender)) {}

    function getBalance(uint account, uint id) internal view override returns (uint) {
        return balances[account][id];
    }

    function inject(bytes[] calldata steps) external payable override onlyOwner returns (uint) {
        return pipe(ENTRY, abi.encode(admin, ""), steps, Value(msg.value));
    }

    // rush javascript -> pipe() factor() sign(steps).. or pipe.sign()
    // add bounty to step instead of fee.
    function execute(bytes[] calldata steps, bytes calldata signed) external payable override returns (uint) {
        address account = validate(steps, signed);
        return pipe(ENTRY, abi.encode(Id.account(account), ""), steps, Value(msg.value));
    }

    function resume(
        bytes4 head,
        bytes memory args,
        bytes[] calldata steps
    ) external payable override onlyAuthorized returns (uint) {
        return pipe(head, args, steps, Value(msg.value));
    }
}
