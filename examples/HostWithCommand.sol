// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";
import {DebitFrom} from "../contracts/Commands.sol";

// Prefer built-in command modules when they already match your use case, then add only the business logic you need.
contract ExampleHost is Host, DebitFrom {
    mapping(bytes32 account => mapping(bytes32 assetRef => uint amount)) internal balances;

    constructor(address cmdr, address disc) Host(cmdr, disc, 1, "example") {}

    // Most reusable command modules work by calling an internal hook like this one, which you override in your host.
    function debitFrom(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override returns (uint) {
        bytes32 ref = keccak256(bytes.concat(asset, meta));
        balances[account][ref] -= amount;
        return amount;
    }
}
