// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";
import {CommandContext} from "../contracts/Commands.sol";
import {AssetAmount} from "../contracts/Schema.sol";
import {MapBalance} from "../contracts/combinators/MapBalance.sol";
import {toCommandId} from "../contracts/Utils.sol";

bytes32 constant NAME = "myCommand";

contract ExampleHost is Host, MapBalance {
    uint immutable myCommandId = toCommandId(NAME, address(this));

    constructor(address cmdr, address disc) Host(cmdr, disc, 1, "example") {
        emit Command(host, NAME, "", myCommandId, 0, 0);
    }

    function mapBalance(
        bytes32, // account
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal pure override returns (bool keep, AssetAmount memory out) {
        // explain map can return some other asset. transforming from one asset to another.
        return (true, AssetAmount(asset, meta, amount / 2));
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        return mapBalances(c.state, 0, c.account);
    }
}
