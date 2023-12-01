// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum } from '../SparkPayloadEthereum.sol';

/**
 * @title  November 29, 2023 Spark Ethereum Proposal - Set DAI supply spread to 0.5%
 * @author Phoenix Labs
 * @dev    This proposal updates DAI Interest Rate Strategy supplySpread parameter to match borrowSpread parameter.
 * Forum:  https://forum.makerdao.com/t/accounting-discrepancy-in-the-dai-market/22845
 */
contract SparkEthereum_20231129 is SparkPayloadEthereum {

    address public constant DAI                            = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x7d8f2210FAD012E7d260C3ddBeCaCfd48277455F;

    function _postExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            NEW_DAI_INTEREST_RATE_STRATEGY
        );
    }

}
