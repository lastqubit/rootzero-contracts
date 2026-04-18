// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Deposit } from "../commands/Deposit.sol";
import { PeerPull } from "../peer/Pull.sol";
import { GetBalances } from "../queries/Balances.sol";
import { Cur } from "../Cursors.sol";
import { Ids } from "../utils/Ids.sol";

contract TestCompositeHost is Host, Deposit, PeerPull, GetBalances {
    constructor(address cmdr)
        Host(address(0), 1, "test")
        Deposit()
        PeerPull("")
        GetBalances()
    {
        if (cmdr != address(0)) access(Ids.toHost(cmdr), true);
    }

    function deposit(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal pure override {
        account; asset; meta; amount;
    }

    function peerPull(uint peer, Cur memory input) internal pure override {
        peer; input;
    }

    function getBalance(bytes32 account, bytes32 asset, bytes32 meta) internal pure override returns (uint amount) {
        account; asset; meta;
        return 0;
    }
}
