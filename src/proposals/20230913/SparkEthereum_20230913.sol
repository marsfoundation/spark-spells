// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum } from '../../SparkPayloadEthereum.sol';

/**
 * @title  September 13, 2023 Spark Ethereum Proposal - Set DAI borrow spread to 0.5%, set flash loan fee to 0
 * @author Phoenix Labs
 * @dev    This proposal updates DAI Interest Rate Strategy borrowSpread parameter and updates FLASHLOAN_PREMIUM_TOTAL pool parameter
 * Forum:           https://forum.makerdao.com/t/upcoming-spell-proposed-changes/21801
 * DAI Vote:        https://vote.makerdao.com/polling/QmQrkxud
 * Flash Loan Vote: https://vote.makerdao.com/polling/QmbCDKof
 */
contract SparkEthereum_20230913 is SparkPayloadEthereum {

    address public constant DAI                            = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x41709f51E59ddbEbF37cE95257b2E4f2884a45F8;

    uint128 public constant NEW_FLASHLOAN_PREMIUM_TOTAL = 0;

    function _postExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            NEW_DAI_INTEREST_RATE_STRATEGY
        );

        LISTING_ENGINE.POOL_CONFIGURATOR().updateFlashloanPremiumTotal(
            NEW_FLASHLOAN_PREMIUM_TOTAL
        );
    }
}
