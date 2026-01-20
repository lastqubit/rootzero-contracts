// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import "hardhat/console.sol";

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
    )
        Node(address(0), discovery, "admin")
        Ownable(Addr.or(owner, msg.sender))
    {}

    /*     function toId(address addr) public view returns (uint) {
        return Id.create(addr); /////
    } */

    function settle(
        uint from,
        uint to,
        uint id,
        uint amount
    ) internal override returns (bool) {
        // return if out == in ??
        return debitFrom(from, id, amount) == creditTo(to, id, amount);
    }

    function inject(
        bytes32 head, // remove ??
        bytes memory body,
        bytes[] calldata steps
    ) external payable override onlyOwner returns (uint) {
        uint account = Id.account(admin);
        return pipe(account, head, body, steps, Value(msg.value));
    }

    function resume(
        bytes32 head, // ensure not zero ??
        bytes memory body,
        bytes calldata signed,
        bytes[] calldata steps
    ) external payable override onlyAuthorized returns (uint) {
        uint account = validate(signed, steps);
        return pipe(account, head, body, steps, Value(msg.value)); // If not signed, from becomes calling node!!
    }

    function execute(
        bytes calldata signed,
        bytes[] calldata steps
    ) external payable override returns (uint) {
        uint account = validate(signed, steps);
        return pipe(account, 0, "", steps, Value(msg.value));
    }

    function getBalances(
        uint account,
        uint[] calldata ids
    ) external view override returns (uint[] memory) {
        uint[] memory result = new uint[](ids.length);
        for (uint i = 0; i < ids.length; i++) {
            result[i] = balances[account][ids[i]];
        }
        return result;
    }
}
