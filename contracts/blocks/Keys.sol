// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

library Keys {
    bytes4 constant Amount = bytes4(keccak256("amount(bytes32 asset, bytes32 meta, uint amount)"));
    bytes4 constant Balance = bytes4(keccak256("balance(bytes32 asset, bytes32 meta, uint amount)"));
    bytes4 constant Custody = bytes4(keccak256("custody(uint host, bytes32 asset, bytes32 meta, uint amount)"));
    bytes4 constant Minimum = bytes4(keccak256("minimum(bytes32 asset, bytes32 meta, uint amount)"));
    bytes4 constant Maximum = bytes4(keccak256("maximum(bytes32 asset, bytes32 meta, uint amount)"));
    bytes4 constant Break = bytes4(keccak256("break()"));
    bytes4 constant Bundle = bytes4(keccak256("bundle(bytes data)"));
    bytes4 constant Route = bytes4(keccak256("route(bytes data)"));
    bytes4 constant Quantity = bytes4(keccak256("quantity(uint amount)"));
    bytes4 constant Rate = bytes4(keccak256("rate(uint value)"));
    bytes4 constant Party = bytes4(keccak256("party(bytes32 account)"));
    bytes4 constant Recipient = bytes4(keccak256("recipient(bytes32 account)"));
    bytes4 constant Transaction = bytes4(keccak256("tx(bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount)"));
    bytes4 constant Step = bytes4(keccak256("step(uint target, uint value, bytes request)"));
    bytes4 constant Auth = bytes4(keccak256("auth(uint cid, uint deadline, bytes proof)"));
    bytes4 constant Asset = bytes4(keccak256("asset(bytes32 asset, bytes32 meta)"));
    bytes4 constant Node = bytes4(keccak256("node(uint id)"));
    bytes4 constant Listing = bytes4(keccak256("listing(uint host, bytes32 asset, bytes32 meta)"));
    bytes4 constant Funding = bytes4(keccak256("funding(uint host, uint amount)"));
    bytes4 constant Allocation = bytes4(keccak256("allocation(uint host, bytes32 asset, bytes32 meta, uint amount)"));
    bytes4 constant Bounty = bytes4(keccak256("bounty(uint amount, bytes32 relayer)"));
}



