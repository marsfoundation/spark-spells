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

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);

        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     WSTETH,
            supplyCap: 10_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

    function rateStrategiesUpdates()
        public pure override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory wethRateStrategyParams = Rates.RateStrategyParams({
            optimalUsageRatio:             _bpsToRay(90_00),
            baseVariableBorrowRate:        0,
            variableRateSlope1:            _bpsToRay(3_20),
            variableRateSlope2:            _bpsToRay(120_00),
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
