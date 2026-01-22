// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

//import {Tx} from "./Io.sol";

/* struct Discover {
    address addr;
    uint id;
    bytes32 name;
} */

struct Tx {
    uint from;
    uint to;
    uint id;
    uint amount;
}

struct Packet {
    uint ref; // bytes head
    uint account;
    uint id;
    uint amount;
}

struct Event {
    uint ref;
    uint id;
    uint amount;
    bytes32 to; // uint
    bytes call;
}

/* struct Input {
    bytes4 selector;
    bytes params;
    bytes step;
} */

/* struct Rush {
    uint id;
    uint min;
    uint max;
    uint fee;
    bytes32 steps;
} */

/* struct Signed {
    uint head; // validator: patched nodeId, version SIGNED
    uint meta; // deadline:exec
    bytes sig;
    bytes data; // bytes with meta signer
}
 */
