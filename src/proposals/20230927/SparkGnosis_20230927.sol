// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGnosis, IEngine, Rates, EngineFlags } from '../../SparkPayloadGnosis.sol';

/**
 * @title  September 27, 2023 Spark Gnosis Proposal - Activate Gnosis Chain instance
 * @author Phoenix Labs
 * @dev    This proposal activates the Gnosis Chain instance of Spark Lend
 * Forum:  https://forum.makerdao.com/t/proposal-for-activation-of-gnosis-chain-instance/22098
 * Vote:   TODO
 */
contract SparkGnosis_20230927 is SparkPayloadGnosis {

    address public constant WXDAI             = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;
    address public constant WXDAI_PRICE_FEED  = 0x678df3415fc31947dA4324eC63212874be5a82f8;
    address public constant WETH              = 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;
    address public constant WETH_PRICE_FEED   = 0xa767f745331D267c7751297D982b050c93985627;
    address public constant WSTETH            = 0x6C76971f98945AE98dD7d4DFcA8711ebea946eA6;
    address public constant WSTETH_PRICE_FEED = 0xae27e63307963850c4d30BFba78FC1116d7b48C3;
    address public constant GNO               = 0x9C58BAcC331c9aa871AFD802DB6379a98e80CEdb;
    address public constant GNO_PRICE_FEED    = 0x22441d81416430A54336aB28765abd31a792Ad37;

    function _preExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().setEModeCategory(
            1,
            85_00,
            90_00,
            103_00,
            address(0),
            "ETH"
        );
    }

    function newListings() public pure override returns (IEngine.Listing[] memory) {
        IEngine.Listing[] memory listings = new IEngine.Listing[](4);

        // wxDAI
        listings[0] = IEngine.Listing({
            asset:              WXDAI,
            assetSymbol:        'WXDAI',
            priceFeed:          WXDAI_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(90_00),
                baseVariableBorrowRate:        48790164207174267760128000,      // DSR expressed as a yearly APR [RAY]
                variableRateSlope1:            0,
                variableRateSlope2:            _bpsToRay(50_00),
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseStableRateOffset:          0,
                stableRateExcessOffset:        0,
                optimalStableToTotalDebtRatio: 0
            }),
            enabledToBorrow:       EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.ENABLED,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            flashloanable:         EngineFlags.ENABLED,
            ltv:                   70_00,
            liqThreshold:          75_00,
            liqBonus:              5_00,
            // NOTE reserve factor needs to be set > 0 for the config engine (soft constraint), set it to 1bps here and set it to 0 manually in _postExecute
            // https://github.com/bgd-labs/aave-helpers/blob/master/src/v3-config-engine/libraries/BorrowEngine.sol#L60
            reserveFactor:         1,
            supplyCap:             10_000_000,
            borrowCap:             8_000_000,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        // WETH
        listings[1] = IEngine.Listing({
            asset:              WETH,
            assetSymbol:        'WETH',
            priceFeed:          WETH_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(90_00),
                baseVariableBorrowRate:        _bpsToRay(1_00),
                variableRateSlope1:            _bpsToRay(2_80),
                variableRateSlope2:            _bpsToRay(120_00),
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseStableRateOffset:          0,
                stableRateExcessOffset:        0,
                optimalStableToTotalDebtRatio: 0
            }),
            enabledToBorrow:       EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            flashloanable:         EngineFlags.ENABLED,
            ltv:                   70_00,
            liqThreshold:          75_00,
            liqBonus:              5_00,
            reserveFactor:         10_00,
            supplyCap:             5_000,
            borrowCap:             3_000,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         1
        });

        // wstETH
        listings[2] = IEngine.Listing({
            asset:              WSTETH,
            assetSymbol:        'wstETH',
            priceFeed:          WSTETH_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(45_00),
                baseVariableBorrowRate:        _bpsToRay(1_00),
                variableRateSlope1:            _bpsToRay(3_00),
                variableRateSlope2:            _bpsToRay(100_00),
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseStableRateOffset:          0,
                stableRateExcessOffset:        0,
                optimalStableToTotalDebtRatio: 0
            }),
            enabledToBorrow:       EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            flashloanable:         EngineFlags.ENABLED,
            ltv:                   65_00,
            liqThreshold:          72_50,
            liqBonus:              8_00,
            reserveFactor:         30_00,
            supplyCap:             5_000,
            borrowCap:             100,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         1
        });

        // GNO
        listings[3] = IEngine.Listing({
            asset:              GNO,
            assetSymbol:        'GNO',
            priceFeed:          GNO_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(80_00),   // Needs to be > 0, but doesn't matter the value beyond that
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0,
                variableRateSlope2:            0,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseStableRateOffset:          0,
                stableRateExcessOffset:        0,
                optimalStableToTotalDebtRatio: 0
            }),
            enabledToBorrow:       EngineFlags.DISABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            flashloanable:         EngineFlags.ENABLED,
            ltv:                   40_00,
            liqThreshold:          50_00,
            liqBonus:              12_00,
            // NOTE reserve factor needs to be set > 0 for the config engine (soft constraint), set it to 1bps here and set it to 0 manually in _postExecute
            // https://github.com/bgd-labs/aave-helpers/blob/master/src/v3-config-engine/libraries/BorrowEngine.sol#L60
            reserveFactor:         1,
            supplyCap:             200_000,
            borrowCap:             0,
            debtCeiling:           1_000_000,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        return listings;
    }

    function _postExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveFactor(WXDAI, 0);
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveFactor(GNO, 0);
    }

}
