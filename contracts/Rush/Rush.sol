// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Executor, Value, Ownable} from "./Executor.sol";
import {Node} from "../Lib/Node.sol";
import {Id} from "../Lib/Utils/Id.sol";
import {addrOr} from "../Lib/Utils/Utils.sol";

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
        return pipe(admin, 0, "", steps, Value(msg.value)); // make admin uint
    }

    // add bounty to step instead of fee.
    // account not allowed to change thru pipeline. must be local account
    function execute(bytes[] calldata steps, bytes calldata signed) external payable override returns (uint) {
        return pipe(validate(steps, signed), 0, "", steps, Value(msg.value));
    }

    function resume(
        bytes32 head,
        bytes memory body,
        bytes[] calldata steps,
        bytes calldata signed
    ) external payable override onlyAuthorized returns (uint) {
        return pipe(validate(steps, signed), head, body, steps, Value(msg.value)); // If not signed, from becomes calling node!!
    }
}
