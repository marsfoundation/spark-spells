// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGoerli, IEngine, Rates, EngineFlags } from '../../SparkPayloadGoerli.sol';

import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  August 30, 2023 Spark Goerli Proposal - Update ETH Kink, Update ETHn Kink Rate, Update wstETH Supply Cap
 * @author Phoenix Labs
 * @dev    This proposal updates ETH market kink parameters and raises wstETH supply cap
 * Forum:  *TBA*
 * Vote:   N/A
 */
contract SparkGoerli_20230830 is SparkPayloadGoerli {

    address public constant WETH                           = 0x7D5afF7ab67b431cDFA6A94d50d3124cC4AB2611;
    uint256 public constant NEW_WETH_OPTIMAL_USAGE_RATIO   = 0.90e27;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_1 = 0.028e27;

    address public constant wstETH                         = 0x6E4F1e8d4c5E5E6e2781FD814EE0744cc16Eb352;
    uint256 public constant NEW_WSTETH_SUPPLY_CAP          = 400_000;

    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory weth = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(WETH);

        weth.optimalUsageRatio = NEW_WETH_OPTIMAL_USAGE_RATIO;
        weth.variableRateSlope1 = NEW_WETH_VARIABLE_RATE_SLOPE_1;

        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  WETH,
            params: weth
        });

        return ratesUpdate;
    }

    function capsUpdates()
        public view override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);
        capsUpdate[0] = IEngine.CapsUpdate({
            asset: wstETH,
            supplyCap: NEW_WSTETH_SUPPLY_CAP,
            borrowCap: EngineFlags.KEEP_CURRENT 
        });

        return capsUpdate;
    }
}