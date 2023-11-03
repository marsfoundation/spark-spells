// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title  November 15, 2023 Spark Ethereum Proposal -
 * @author Phoenix Labs
 * @dev
 * Forum:
 * Vote:
 */
contract SparkEthereum_20231115 is SparkPayloadEthereum {
    address public constant RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 public constant NEW_RETH_SUPPLY_CAP            = 80_000;
    uint256 public constant NEW_WSTETH_SUPPLY_CAP          = 800_000;
    uint256 public constant NEW_DAI_LTV                    = 0;
    uint256 public constant WETH_OPTIMAL_USAGE_RATIO   = 90_00;
    uint256 public constant NEW_WETH_BASE_RATE             = 0;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_1 = 3_20;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_2 = 123_20;

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](2);
        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     RETH,
            supplyCap: NEW_RETH_SUPPLY_CAP,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        capsUpdate[1] = IEngine.CapsUpdate({
            asset:     WSTETH,
            supplyCap: NEW_WSTETH_SUPPLY_CAP,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

    function collateralsUpdates()
        public pure override returns (IEngine.CollateralUpdate[] memory)
    {
        IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);

        collateralUpdates[0] = IEngine.CollateralUpdate({
            asset:          DAI,
            ltv:            NEW_DAI_LTV,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return collateralUpdates;
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
