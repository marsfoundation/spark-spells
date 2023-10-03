// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title  October 11, 2023 Spark Ethereum Proposal -
 * @author Phoenix Labs
 * @dev
 * Forum:
 * Vote:
 */
contract SparkEthereum_20231011 is SparkPayloadEthereum {

    address public constant SDAI            = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address public constant RETH            = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant USDC            = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_PRICE_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant USDT            = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDT_PRICE_FEED = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;

    uint256 public constant VARIABLE_RATE   = 44790164207174267760128000; // DSR - 0.4% expressed as a yearly APR [RAY]

    function _preExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().setEModeCategory(
            2,
            91_00,
            92_00,
            101_00,
            address(0),
            'USD'
        );
    }

    function newListings()
        public pure override returns (IEngine.Listing[] memory)
    {
        IEngine.Listing[] memory listings = new IEngine.Listing[](1);

        listings[0] = IEngine.Listing({
            asset:              USDT,
            assetSymbol:        'USDT',
            priceFeed:          USDT_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(95_00),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            VARIABLE_RATE,
                variableRateSlope2:            _bpsToRay(20_00),
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseStableRateOffset:          0,
                stableRateExcessOffset:        0,
                optimalStableToTotalDebtRatio: 0
            }),
            enabledToBorrow:       EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing:   EngineFlags.ENABLED,
            flashloanable:         EngineFlags.ENABLED,
            ltv:                   0,
            liqThreshold:          0,
            liqBonus:              0,
            reserveFactor:         5_00,
            supplyCap:             30_000_000,
            borrowCap:             0,
            debtCeiling:           0,
            liqProtocolFee:        0,
            eModeCategory:         2
        });

        return listings;
    }

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](2);

        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     RETH,
            supplyCap: 60_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        capsUpdate[1] = IEngine.CapsUpdate({
            asset:     USDC,
            supplyCap: 60_000_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

    function collateralsUpdates()
        public pure override returns (IEngine.CollateralUpdate[] memory)
    {
        IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](2);

        collateralUpdates[0] = IEngine.CollateralUpdate({
            asset:          SDAI,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  2
        });

        collateralUpdates[1] = IEngine.CollateralUpdate({
            asset:          USDC,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  2
        });

        return collateralUpdates;
    }

    function borrowsUpdates()
        public pure override returns (IEngine.BorrowUpdate[] memory)
    {
        IEngine.BorrowUpdate[] memory borrowsUpdate = new IEngine.BorrowUpdate[](1);

        borrowsUpdate[0] = IEngine.BorrowUpdate({
            asset:                 USDC,
            reserveFactor:         5_00,
            enabledToBorrow:       EngineFlags.ENABLED,
            flashloanable:         EngineFlags.KEEP_CURRENT,
            stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
            borrowableInIsolation: EngineFlags.KEEP_CURRENT,
            withSiloedBorrowing:   EngineFlags.ENABLED
        });

        return borrowsUpdate;
    }

    function priceFeedsUpdates()
        public pure override returns (IEngine.PriceFeedUpdate[] memory)
    {
        IEngine.PriceFeedUpdate[] memory priceFeedsUpdate = new IEngine.PriceFeedUpdate[](1);

        priceFeedsUpdate[0] = IEngine.PriceFeedUpdate({
            asset:     USDC,
            priceFeed: USDC_PRICE_FEED
        });

        return priceFeedsUpdate;
    }

    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory usdcRateStrategyParams = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(USDC);

        usdcRateStrategyParams.optimalUsageRatio      = _bpsToRay(95_00);
        usdcRateStrategyParams.baseVariableBorrowRate = 0;
        usdcRateStrategyParams.variableRateSlope1     = VARIABLE_RATE;
        usdcRateStrategyParams.variableRateSlope2     = _bpsToRay(20_00);

        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  USDC,
            params: usdcRateStrategyParams
        });

        return ratesUpdate;
    }
}
