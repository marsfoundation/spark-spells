// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum } from '../../SparkPayloadEthereum.sol';

/**
 * @title  September 13, 2023 Spark Ethereum Proposal - Set DAI borrow spread to 0.5%, set flash loan fee to 0
 * @author Phoenix Labs
 * @dev    This proposal updates DAI Interest Rate Strategy borrowSpread parameter and updates FLASHLOAN_PREMIUM_TOTAL parameter
 * Forum:           https://forum.makerdao.com/t/phoenix-labs-proposed-changes-for-spark-for-next-upcoming-spell/21685
 * DAI Vote:        https://vote.makerdao.com/polling/QmQrkxud
 * Flash Loan Vote: https://vote.makerdao.com/polling/QmbCDKof
 */
contract SparkEthereum_20230913 is SparkPayloadEthereum {
    uint128 public constant NEW_FLASHLOAN_PREMIUM_TOTAL = 0;

    function _postExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().updateFlashloanPremiumTotal(
            NEW_FLASHLOAN_PREMIUM_TOTAL
        );
    }
}
