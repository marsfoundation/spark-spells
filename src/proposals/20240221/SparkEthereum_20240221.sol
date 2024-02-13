// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum } from '../../SparkPayloadEthereum.sol';

/**
 * @title  February 21, 2024 Spark Ethereum Proposal - Increase DAI IRM spread
 * @author Phoenix Labs
 * @dev    This proposal sets increases the DAI IRM spread to 6.58%
 * Forum: TODO
 * Vote:  N/A
 */
contract SparkEthereum_20240221 is SparkPayloadEthereum {

    address public constant DAI                = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    function _postExecute()
        internal override
    {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_IRM
        );
    }

}
