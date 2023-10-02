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
    address public constant RETH            = 0xae78736cd615f374d3085123a210448e74fc6393;
    address public constant USDC            = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;
    address public constant USDC_PRICE_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant USDT            = 0xdac17f958d2ee523a2206206994597c13d831ec7;
    address public constant USDT_PRICE_FEED = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;

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

    function capsUpdates() public pure override returns (IEngine.CapsUpdate[] memory) {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);

        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     RETH,
            supplyCap: 60_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
        IEngine.CollateralUpdate[] memory collateralUpdate = new IEngine.CollateralUpdate[](1);

        collateralUpdate[0] = IEngine.CollateralUpdate({
            asset: SDAI,
            ltv: EngineFlags.KEEP_CURRENT,
            liqThreshold: EngineFlags.KEEP_CURRENT,
            liqBonus: EngineFlags.KEEP_CURRENT,
            debtCeiling: EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory: 2
        });

        return collateralUpdate;
    }

    function newListings() public pure override returns (IEngine.Listing[] memory) {
        IEngine.Listing[] memory listings = new IEngine.Listing[](2);

        listings[0] = IEngine.Listing({
            asset:              USDC,
            assetSymbol:        'USDC',
            priceFeed:          USDC_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(95_00),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            44790164207174267760128000, // DSR - 0.4% expressed as a yearly APR [RAY]
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
            supplyCap:             60_000_000,
            borrowCap:             0,
            debtCeiling:           0,
            liqProtocolFee:        0,
            eModeCategory:         2
        });

        listings[1] = IEngine.Listing({
            asset:              USDT,
            assetSymbol:        'USDT',
            priceFeed:          USDT_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(95_00),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            44790164207174267760128000, // DSR - 0.4% expressed as a yearly APR [RAY]
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
}
