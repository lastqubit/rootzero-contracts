// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";
import {CommandContext} from "../contracts/Commands.sol";
import {AssetAmount} from "../contracts/Schema.sol";
import {MapBalance} from "../contracts/combinators/MapBalance.sol";
import {toCommandId} from "../contracts/Utils.sol";

string constant NAME = "myCommand";

contract ExampleHost is Host, MapBalance {
    uint immutable myCommandId = commandId(NAME);

    constructor(address rush) Host(rush, 1, "example") {
        emit Command(host, NAME, "", myCommandId, 0, 0);
    }

    function mapBalance(
        bytes32, // account
        AssetAmount memory balance
    ) internal pure override returns (AssetAmount memory out) {
        // explain map can return some other asset. transforming from one asset to another.
        return AssetAmount(balance.asset, balance.meta, balance.amount / 2);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        return mapBalances(c.state, 0, c.account);
    }
}
