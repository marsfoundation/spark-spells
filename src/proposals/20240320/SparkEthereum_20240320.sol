// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { ICapAutomator } from '../../interfaces/ICapAutomator.sol';

import { SparkPayloadEthereum } from '../../SparkPayloadEthereum.sol';

/**
 * @title  March 20, 2024 Spark Ethereum Proposal - Raise maximum supply cap in Cao Automator to 6,000 for WBTC
 * @author Phoenix Labs
 * @dev    This proposal changes the max parameter in supplyCapConfig in CapAutomator for WBTC market
 * Forum:  https://forum.makerdao.com/t/mar-6-2024-proposed-changes-to-sparklend-for-upcoming-spell/23791
 * Votes:  TODO
 */
contract SparkEthereum_20240320 is SparkPayloadEthereum {

    address internal constant CAP_AUTOMATOR = 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef;
    address internal constant WBTC          = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    function _postExecute()
        internal override
    {
        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: WBTC, max: 6_000, gap: 500, increaseCooldown: 12 hours});
    }

}
