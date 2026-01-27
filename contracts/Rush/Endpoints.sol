// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Inject} from "../Lib/Commands/Core/Entry/Inject.sol";
import {Pipe} from "../Lib/Commands/Core/Entry/Pipe.sol";
import {Resume} from "../Lib/Commands/Core/Entry/Resume.sol";
import {Balances} from "../Lib/Snippets/Balances.sol";
import {GetBalances} from "../Lib/Queries/GetBalances.sol";

abstract contract Endpoints is Inject, Pipe, Resume, Balances, GetBalances {}
