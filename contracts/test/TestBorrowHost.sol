// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../core/Host.sol";
import {BorrowAgainstCustodyToBalance} from "../commands/Borrow.sol";
import {AssetAmount, HostAmount, DataRef} from "../blocks/Schema.sol";
import {Data} from "../blocks/Data.sol";
import {toHostId} from "../utils/Ids.sol";

using Data for DataRef;

contract TestBorrowHost is Host, BorrowAgainstCustodyToBalance {
    event BorrowCalled(bytes32 account, bytes32 asset, bytes32 meta, uint amount, bytes routeData);

    bytes32 public returnAsset;
    bytes32 public returnMeta;
    uint public returnAmount;

    constructor(address cmdr) Host(address(0), 1, "test") BorrowAgainstCustodyToBalance("") {
        if (cmdr != address(0)) access(toHostId(cmdr), true);
    }

    function setReturn(bytes32 asset, bytes32 meta, uint amount) external {
        returnAsset = asset;
        returnMeta = meta;
        returnAmount = amount;
    }

    function borrowAgainstCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute
    ) internal override returns (AssetAmount memory) {
        bytes calldata routeData = msg.data[rawRoute.i:rawRoute.bound];
        emit BorrowCalled(account, custody.asset, custody.meta, custody.amount, routeData);
        return AssetAmount({asset: returnAsset, meta: returnMeta, amount: returnAmount});
    }

    function getBorrowId() external view returns (uint) {
        return borrowAgainstCustodyToBalanceId;
    }

    function getAdminAccount() external view returns (bytes32) {
        return adminAccount;
    }
}
