// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Deposit } from "../commands/Deposit.sol";
import { PeerRedeemBalance } from "../peer/Redeem.sol";
import { GetBalances } from "../queries/Balances.sol";
import { Nodes } from "../utils/Nodes.sol";

contract TestCompositeHost is Host, Deposit, PeerRedeemBalance, GetBalances {
    constructor(address cmdr)
        Host(address(0))
        Deposit()
        PeerRedeemBalance()
        GetBalances()
    {
        if (cmdr != address(0)) setNode(Nodes.toHost(cmdr), true);
    }

    function deposit(bytes32 account, bytes32 asset, uint amount) internal pure override {
        account; asset; amount;
    }

    function redeemBalance(uint peer, bytes32 asset, uint amount) internal pure override {
        peer; asset; amount;
    }

    function getBalance(bytes32 account, bytes32 asset) internal pure override returns (uint amount) {
        account; asset;
        return 0;
    }
}
