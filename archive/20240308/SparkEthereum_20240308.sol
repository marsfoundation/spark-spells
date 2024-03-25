// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum } from '../../SparkPayloadEthereum.sol';

/**
 * @title  March 08, 2024 Spark Ethereum Proposal - Increase DAI interest rate
 * @author Phoenix Labs
 * @dev    This proposal increases the DAI borrow interest rate to 16% by setting a new interest rate strategy
 */
contract SparkEthereum_20240308 is SparkPayloadEthereum {

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Formula for 16% target APY (0.008658062782674090146928000 spread at current DSR):
    // bc -l <<< 'scale=27; (e( l(1.16)/(60 * 60 * 24 * 365) ) - 1) * 60 * 60 * 24 * 365 - 0.139761942684858731695536000'
    address public constant DAI_IRM = 0x7949a8Ef09c49506cCB1cB983317272dcf4170Dd;

    function _postExecute()
        internal override
    {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_IRM
        );
    }

}
