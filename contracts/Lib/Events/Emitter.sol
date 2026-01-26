// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

abstract contract EventEmitter {
    event EventDesc(
        bool once,
        string category,
        string abi
    );
}
