// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Inject} from "../Lib/Commands/Entry/Inject.sol";
import {Execute} from "../Lib/Commands/Entry/Execute.sol";
import {Resume} from "../Lib/Commands/Entry/Resume.sol";
import {GetBalances} from "../Lib/Queries/GetBalances.sol";
import {Balances} from "../Lib/Balances.sol";

abstract contract Endpoints is Inject, Execute, Resume, Balances, GetBalances {}
