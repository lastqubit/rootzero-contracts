// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { HostAmount, Cursors, Cur, Writers, Writer } from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract MapCustody {
    function mapCustody(bytes32 account, HostAmount memory custody) internal virtual returns (HostAmount memory out);

    function mapCustodies(bytes calldata state, uint i, bytes32 account) internal returns (bytes memory) {
        (Cur memory scan, , uint count) = Cursors.init(state[i:], 1);
        Writer memory writer = Writers.allocCustodies(count);

        while (scan.i < scan.bound) {
            HostAmount memory custody = scan.unpackCustodyValue();
            HostAmount memory out = mapCustody(account, custody);
            if (out.amount > 0) writer.appendCustody(out);
        }

        return writer.finish();
    }
}





