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
    address public constant RETH            = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant WSTETH          = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant DAI             = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH            = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WBTC            = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WBTC_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](3);
        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     RETH,
            supplyCap: 80_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        capsUpdate[1] = IEngine.CapsUpdate({
            asset:     WSTETH,
            supplyCap: 800_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        capsUpdate[2] = IEngine.CapsUpdate({
            asset:     WBTC,
            supplyCap: 3_000,
            borrowCap: 2_000
        });

        return capsUpdate;
    }

    function collateralsUpdates()
        public pure override returns (IEngine.CollateralUpdate[] memory)
    {
        IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](2);

        collateralUpdates[0] = IEngine.CollateralUpdate({
            asset:          DAI,
            ltv:            0,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[1] = IEngine.CollateralUpdate({
            asset:          WBTC,
            ltv:            70_00,
            liqThreshold:   75_00,
            liqBonus:       7_00,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return collateralUpdates;
    }

    function borrowsUpdates()
        public pure override returns (IEngine.BorrowUpdate[] memory)
    {
        IEngine.BorrowUpdate[] memory borrowsUpdate = new IEngine.BorrowUpdate[](1);

        borrowsUpdate[0] = IEngine.BorrowUpdate({
            asset:                 WBTC,
            reserveFactor:         20_00,
            enabledToBorrow:       EngineFlags.ENABLED,
            flashloanable:         EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing:   EngineFlags.ENABLED
        });

        return borrowsUpdate;
    }

    function rateStrategiesUpdates()
        public pure override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](2);

        Rates.RateStrategyParams memory wethRateStrategyParams = Rates.RateStrategyParams({
            optimalUsageRatio:             _bpsToRay(90_00),
            baseVariableBorrowRate:        0,
            variableRateSlope1:            _bpsToRay(3_20),
            variableRateSlope2:            _bpsToRay(123_20),
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

        Rates.RateStrategyParams memory wbtcRateStrategyParams = Rates.RateStrategyParams({
            optimalUsageRatio:             _bpsToRay(60_00),
            baseVariableBorrowRate:        0,
            variableRateSlope1:            _bpsToRay(2_00),
            variableRateSlope2:            _bpsToRay(302_00),
            stableRateSlope1:              0,
            stableRateSlope2:              0,
            baseStableRateOffset:          0,
            stableRateExcessOffset:        0,
            optimalStableToTotalDebtRatio: 0
        });

        ratesUpdate[1] = IEngine.RateStrategyUpdate({
            asset:  WBTC,
            params: wbtcRateStrategyParams
        });

        return ratesUpdate;
    }

    function _postExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveFreeze(
            WBTC,
            false
        );
    }

}
