// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGoerli, IEngine, Rates } from '../../SparkPayloadGoerli.sol';

import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  August 30, 2023 Spark Goerli Proposal - Update ETH Kink, Update ETHn Kink Rate, Update wstETH Supply Cap
 * @author Phoenix Labs
 * @dev    This proposal updates ETH market kink parameters and raises wstETH supply cap
 * Forum:  *TBA*
 * Vote:   N/A
 */
contract SparkGoerli_20230830 is SparkPayloadGoerli {
    address public constant WETH = 0x7D5afF7ab67b431cDFA6A94d50d3124cC4AB2611;

    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory weth = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(WETH);

        weth.variableRateSlope1 = _bpsToRay(3_80);
        weth.optimalUsageRatio = _bpsToRay(90_00);

        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  WETH,
            params: weth
        });

        return ratesUpdate;
    }
}