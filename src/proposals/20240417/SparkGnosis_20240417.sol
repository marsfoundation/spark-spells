// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGnosis, Gnosis, IEngine, Rates, EngineFlags } from 'src/SparkPayloadGnosis.sol';

import { IPoolAddressesProvider } from 'sparklend-v1-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  April 17, 2024 Spark Gnosis Proposal
 * @notice Upgrade Pool Implementation to SparkLend V1.0.0, onboard sxDAI/EURe/USDC/USDT, parameter refresh.
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/apr-4-2024-proposed-changes-to-sparklend-for-upcoming-spell/24033
 * Votes:  TODO
 */
contract SparkGnosis_20240417 is SparkPayloadGnosis {

    address public constant POOL_IMPLEMENTATION_NEW = 0xCF86A65779e88bedfF0319FE13aE2B47358EB1bF;

    address public constant SXDAI            = 0xaf204776c7245bF4147c2612BF6e5972Ee483701;
    address public constant SXDAI_PRICE_FEED = 0x1D0f881Ce1a646E2f27Dec3c57Fa056cB838BCC2;
    address public constant USDC             = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
    address public constant USDC_PRICE_FEED  = 0x6FC2871B6d9A94866B7260896257Fd5b50c09900;
    address public constant USDT             = 0x4ECaBa5870353805a9F068101A40E0f32ed605C6;
    address public constant USDT_PRICE_FEED  = 0x6FC2871B6d9A94866B7260896257Fd5b50c09900;
    address public constant EURE             = 0xcB444e90D8198415266c6a2724b7900fb12FC56E;
    address public constant EURE_PRICE_FEED  = 0xab70BCB260073d036d1660201e9d5405F5829b7a;

    function newListings() public pure override returns (IEngine.Listing[] memory) {
        IEngine.Listing[] memory listings = new IEngine.Listing[](4);

        // sxDAI
        listings[0] = IEngine.Listing({
            asset:              SXDAI,
            assetSymbol:        'sDAI',
            priceFeed:          SXDAI_PRICE_FEED,
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
            ltv:                   70_00,
            liqThreshold:          75_00,
            liqBonus:              6_00,
            reserveFactor:         10_00,
            supplyCap:             40_000_000,
            borrowCap:             0,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        // USDC
        listings[1] = IEngine.Listing({
            asset:              USDC,
            assetSymbol:        'USDC',
            priceFeed:          USDC_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(90_00),
                baseVariableBorrowRate:        _bpsToRay(0),
                variableRateSlope1:            _bpsToRay(12_00),
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
            withSiloedBorrowing:   EngineFlags.ENABLED,
            flashloanable:         EngineFlags.ENABLED,
            ltv:                   0,
            liqThreshold:          0,
            liqBonus:              0,
            reserveFactor:         10_00,
            supplyCap:             10_000_000,
            borrowCap:             8_000_000,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        // USDT
        listings[2] = IEngine.Listing({
            asset:              USDT,
            assetSymbol:        'USDT',
            priceFeed:          USDT_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(90_00),
                baseVariableBorrowRate:        _bpsToRay(0),
                variableRateSlope1:            _bpsToRay(12_00),
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
            withSiloedBorrowing:   EngineFlags.ENABLED,
            flashloanable:         EngineFlags.ENABLED,
            ltv:                   0,
            liqThreshold:          0,
            liqBonus:              0,
            reserveFactor:         10_00,
            supplyCap:             10_000_000,
            borrowCap:             8_000_000,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        // EURe
        listings[3] = IEngine.Listing({
            asset:              EURE,
            assetSymbol:        'EURe',
            priceFeed:          EURE_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(90_00),
                baseVariableBorrowRate:        _bpsToRay(0),
                variableRateSlope1:            _bpsToRay(7_00),
                variableRateSlope2:            _bpsToRay(50_00),
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
            reserveFactor:         10_00,
            supplyCap:             5_000_000,
            borrowCap:             4_000_000,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        return listings;
    }

    function _postExecute()
        internal override
    {
        // Update Pool Implementation
        IPoolAddressesProvider(Gnosis.POOL_ADDRESSES_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION_NEW);
    }

}
