// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IACLManager } from 'aave-v3-core/contracts/interfaces/IACLManager.sol';

import { SparkPayloadEthereum } from '../../SparkPayloadEthereum.sol';

/**
 * @title  March 06, 2024 Spark Ethereum Proposal - Activate Cap Automator
 * @author Phoenix Labs
 * @dev    This proposal activates the Cap Automator
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkEthereum_20240306 is SparkPayloadEthereum {

    address public constant ACL_MANAGER   = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address public constant CAP_AUTOMATOR = 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef;

    function _postExecute() internal override {
        IACLManager(ACL_MANAGER).addRiskAdmin(CAP_AUTOMATOR);
    }

}
