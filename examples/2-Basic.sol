// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";
import {DebitAccountToBalance} from "../contracts/Commands.sol";

contract ExampleHost is Host, DebitAccountToBalance {
    mapping(bytes32 account => mapping(bytes32 assetRef => uint amount)) internal balances;

    constructor(address rush) Host(rush, 1, "example") {}

    function debitAccountToBalance(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override returns (uint) {
        bytes32 ref = keccak256(bytes.concat(asset, meta));
        balances[account][ref] -= amount;
        return amount;
    }
}
