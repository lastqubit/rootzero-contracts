// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Deposit } from "../commands/Deposit.sol";
import { PeerAssetPull } from "../peer/AssetPull.sol";
import { GetBalances } from "../queries/Balances.sol";
import { Ids } from "../utils/Ids.sol";

contract TestCompositeHost is Host, Deposit, PeerAssetPull, GetBalances {
    constructor(address cmdr)
        Host(address(0), 1, "test")
        Deposit()
        PeerAssetPull()
        GetBalances()
    {
        if (cmdr != address(0)) authorize(Ids.toHost(cmdr));
    }

    function deposit(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal pure override {
        account; asset; meta; amount;
    }

    function peerAssetPull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal pure override {
        peer; asset; meta; amount;
    }

    function getBalance(bytes32 account, bytes32 asset, bytes32 meta) internal pure override returns (uint amount) {
        account; asset; meta;
        return 0;
    }
}
