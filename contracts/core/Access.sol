// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessEvent} from "../events/Access.sol";
import {addrOr, toAdminAccount} from "../utils/Accounts.sol";
import {toHostId} from "../utils/Ids.sol";

abstract contract AccessControl is AccessEvent {
    address internal immutable commander;
    bytes32 internal immutable adminAccount;
    uint public immutable host;

    mapping(uint => bool) internal authorized;

    error UnauthorizedNode(uint node);
    error UnauthorizedCaller(address addr);

    constructor(address cmdr) {
        commander = addrOr(cmdr, address(this));
        adminAccount = toAdminAccount(commander);
        host = toHostId(address(this));
    }

    // @dev inbound auth is host-based.
    function access(uint node, bool allow) internal {
        authorized[node] = allow;
        emit Access(host, node, allow);
    }

    function isTrusted(address caller) internal view returns (bool) {
        return caller == commander || caller == address(this) || authorized[toHostId(caller)];
    }

    function enforceCaller(address caller) internal view returns (address) {
        if (caller == address(0) || !isTrusted(caller)) {
            revert UnauthorizedCaller(caller);
        }
        return caller;
    }

    // @dev Outbound trust check: accepts any authorized node id (host or COMMAND).
    // Inbound caller auth is host-only via `enforceCaller(msg.sender)`.
    function ensureTrusted(uint node) internal view returns (uint) {
        if (node == 0 || !authorized[node]) {
            revert UnauthorizedNode(node);
        }
        return node;
    }
}
