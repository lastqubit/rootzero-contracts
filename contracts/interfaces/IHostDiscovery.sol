// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IHostDiscovery {
    function announceHost(uint id, uint blocknum, uint16 version, string calldata namespace) external;
}
