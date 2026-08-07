// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessDenied, CallerAccess, CommanderAccess} from "./Access.sol";
import {Runtime} from "./Runtime.sol";
import {Annotate} from "../commands/admin/Annotate.sol";
import {Appoint} from "../commands/admin/Appoint.sol";
import {Authorize} from "../commands/admin/Authorize.sol";
import {Dismiss} from "../commands/admin/Dismiss.sol";
import {Unauthorize} from "../commands/admin/Unauthorize.sol";
import {ExecutePayable} from "../commands/admin/Execute.sol";
import {Revoke} from "../guards/Revoke.sol";
import {IntroductionEvent} from "../events/Introduction.sol";
import {Accounts} from "../utils/Accounts.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @title IHostIntroduction
/// @notice Interface implemented by hosts that accept introductions from other hosts.
interface IHostIntroduction {
    /// @notice Record a host introduction claim.
    /// @param peer Host node ID being introduced.
    /// @param blocknum Block number at which the introduction was made.
    function introduce(uint peer, uint blocknum) external;
}

/// @title HostIntroduction
/// @notice Shared deployment-time introduction behavior for rootzero hosts.
/// Calls a deployed commander during construction without adding an inbound
/// introduction endpoint to the inheriting host.
abstract contract HostIntroduction is Runtime {
    /// @param cmdr Commander address to introduce this host to when it is a deployed contract.
    /// @dev Deployment reverts if a contract commander does not accept `introduce(uint,uint)`.
    constructor(address cmdr) {
        if (cmdr == address(0) || cmdr == address(this) || cmdr.code.length == 0) return;
        introduceTo(Nodes.toHost(cmdr));
    }

    /// @notice Introduce this host to the contract address embedded in a local EVM node ID.
    /// @dev Accepts host and endpoint IDs such as commands, ports, queries, and guards.
    /// Reverts when `node` is not local or embeds the zero address.
    /// @param node Local EVM node ID whose underlying contract receives the introduction.
    function introduceTo(uint node) internal {
        IHostIntroduction(Nodes.addr(node)).introduce(host, block.number);
    }
}

/// @title CommandHost
/// @notice Minimal host base for commander-only command execution.
/// Does not include admin commands, peer authorization, guardians, inbound
/// introductions, generic execution, or a native-token receive function.
/// Commands using trusted `NodeCalls` must separately compose a `TrustAccess` policy.
abstract contract CommandHost is CommanderAccess, CallerAccess, HostIntroduction {
    /// @dev Thrown when a commander-only host is deployed without an external commander.
    error InvalidCommander();

    /// @param cmdr Nonzero address allowed to invoke hosted commands.
    constructor(address cmdr) CommanderAccess(cmdr) HostIntroduction(cmdr) {
        if (cmdr == address(0)) revert InvalidCommander();
    }

    function enforceCaller(address caller) internal view virtual override returns (address) {
        return enforceCommander(caller);
    }

}

/// @title Admins
/// @notice Optional bundle of the default host administration commands.
abstract contract Admins is Annotate, ExecutePayable, Authorize, Unauthorize {}

/// @title Guardians
/// @notice Optional bundle for guardian management and the default revoke guard.
abstract contract Guardians is Appoint, Dismiss, Revoke {}

/// @title Host
/// @notice Abstract base contract for rootzero host implementations.
/// Inherits admin command support (authorize, unauthorize, label, executePayable),
/// guardian management, the default guardian revoke action, and
/// optionally introduces itself to a commander host at deployment.
/// Accepts native ETH payments via the `receive` function.
abstract contract Host is
    Admins,
    Guardians,
    HostIntroduction,
    IntroductionEvent,
    IHostIntroduction
{
    /// @param cmdr Commander address; used by the composed access capabilities.
    ///        If `cmdr` is a deployed contract, the host calls `introduce`
    ///        on it during construction.
    constructor(address cmdr) CommanderAccess(cmdr) HostIntroduction(cmdr) {}

    /// @notice Assert that `caller` may invoke commands on a peer-aware host.
    function enforceCaller(address caller) internal view virtual override returns (address) {
        if (caller == address(0) || !isTrustedCaller(caller)) revert AccessDenied();
        return caller;
    }

    /// @notice Record a host introduction claim.
    /// @dev Validates that `peer` matches `msg.sender`; it does not authorize or trust the introduced host.
    /// @param peer Host node ID being introduced.
    /// @param blocknum Block number at which the host was deployed.
    function introduce(uint peer, uint blocknum) external {
        emit Introduction(host, Nodes.matchHost(peer, msg.sender), Accounts.toUser(tx.origin), blocknum);
    }

    /// @notice Accept native ETH transfers (e.g. from command value flows).
    receive() external payable {}
}
