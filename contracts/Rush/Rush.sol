// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Executor, Value, Ownable} from "./Executor.sol";
import {Node} from "../Lib/Node.sol";
import {Id} from "../Lib/Utils/Id.sol";
import {Addr} from "../Lib/Utils/Addr.sol";
import {Bytes} from "../Lib/Utils/Bytes.sol";

contract Rush is Executor {
    mapping(uint => bool) internal initial; /////

    constructor(
        address owner,
        address discovery
    ) Node(address(0), discovery, "admin") Ownable(Addr.or(owner, msg.sender)) {}

    function inject(bytes[] calldata steps) external payable override onlyOwner returns (uint) {
        return pipe(Id.account(admin), 0, "", steps, Value(msg.value)); // make admin uint
    }

    // add bounty to step instead of fee.
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

    function getBalances(uint account, uint[] calldata ids) external view override returns (uint[] memory) {
        uint[] memory result = new uint[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            result[i] = balances[account][ids[i]];
        }
        return result;
    }
}
