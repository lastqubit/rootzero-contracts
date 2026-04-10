// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AssetAmount, HostAmount, Cursors, Cur, Writers, Writer } from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract CustodyToBalance {
    function custodyToBalance(bytes32 account, HostAmount memory custody) internal virtual returns (AssetAmount memory);

    function custodiesToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        Cur memory scan = Cursors.open(blocks[i:]);
        (, uint count) = scan.primeRun(1);
        Writer memory writer = Writers.allocBalances(count);

        while (scan.i < scan.bound) {
            HostAmount memory custody = scan.unpackCustodyValue();
            AssetAmount memory out = custodyToBalance(account, custody);
            writer.appendNonZeroBalance(out);
        }

        return writer.finish();
    }
}





