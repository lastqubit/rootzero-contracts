// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Deposit } from "../commands/Deposit.sol";
import { PeerBalancePull } from "../peer/BalancePull.sol";
import { GetBalances } from "../queries/Balances.sol";
import { Ids } from "../utils/Ids.sol";

contract TestCompositeHost is Host, Deposit, PeerBalancePull, GetBalances {
    constructor(address cmdr)
        Host(address(0))
        Deposit()
        PeerBalancePull()
        GetBalances()
    {
        if (cmdr != address(0)) setNode(Ids.toHost(cmdr), true);
    }

    function deposit(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal pure override {
        account; asset; meta; amount;
    }

    function balancePull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal pure override {
        peer; asset; meta; amount;
    }

    function getBalance(bytes32 account, bytes32 asset, bytes32 meta) internal pure override returns (uint amount) {
        account; asset; meta;
        return 0;
    }
}
