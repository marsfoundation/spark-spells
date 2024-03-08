// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title  March 08, 2024 Spark Ethereum Proposal - Increase DAI interest rate
 * @author Phoenix Labs
 * @dev    This proposal increases the DAI borrow interest rate to 20%  by setting a new interest rate strategy
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkEthereum_20240308 is SparkPayloadEthereum {

    address public constant DAI     = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant DAI_IRM = 0x3C4B090b5b479402e2270C66461D6a62B2054198;  // Add an actual NEW address here

    function _postExecute()
        internal override
    {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_IRM
        );
    }

}
