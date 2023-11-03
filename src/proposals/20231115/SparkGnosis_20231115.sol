// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGnosis, IEngine, Rates, EngineFlags } from '../../SparkPayloadGnosis.sol';

/**
 * @title  November 15, 2023 Spark Gnosis Proposal -
 * @author Phoenix Labs
 * @dev
 * Forum:
 * Vote:
 */
contract SparkGnosis_20231115 is SparkPayloadGnosis {

    address public constant WSTETH = 0x6C76971f98945AE98dD7d4DFcA8711ebea946eA6;
    address public constant WETH   = 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;

    uint256 public constant NEW_WSTETH_SUPPLY_CAP          = 10_000;
    uint256 public constant WETH_OPTIMAL_USAGE_RATIO       = 90_00;
    uint256 public constant NEW_WETH_BASE_RATE             = 0;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_1 = 3_20;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_2 = 123_20;

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);

        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     WSTETH,
            supplyCap: NEW_WSTETH_SUPPLY_CAP,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

    function rateStrategiesUpdates()
        public pure override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory wethRateStrategyParams = Rates.RateStrategyParams({
            optimalUsageRatio:             _bpsToRay(WETH_OPTIMAL_USAGE_RATIO),
            baseVariableBorrowRate:        _bpsToRay(NEW_WETH_BASE_RATE),
            variableRateSlope1:            _bpsToRay(NEW_WETH_VARIABLE_RATE_SLOPE_1),
            variableRateSlope2:            _bpsToRay(NEW_WETH_VARIABLE_RATE_SLOPE_2),
            stableRateSlope1:              0,
            stableRateSlope2:              0,
            baseStableRateOffset:          0,
            stableRateExcessOffset:        0,
            optimalStableToTotalDebtRatio: 0
        });

        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  WETH,
            params: wethRateStrategyParams
        });

        return ratesUpdate;
    }

}
