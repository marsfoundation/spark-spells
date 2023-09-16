// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGnosis, IEngine } from '../../SparkPayloadGnosis.sol';

/**
 * @title  September 27, 2023 Spark Gnosis Proposal - Activate Gnosis Chain instance
 * @author Phoenix Labs
 * @dev    This proposal activates the Gnosis Chain instance of Spark Lend
 * Forum:  https://forum.makerdao.com/t/proposal-for-activation-of-gnosis-chain-instance/22098
 * Vote:   TODO
 */
contract SparkGnosis_20230927 is SparkPayloadGnosis {

    address public constant WXDAI             = ;
    address public constant WXDAI_PRICE_FEED  = 0x678df3415fc31947dA4324eC63212874be5a82f8;
    address public constant WETH              = ;
    address public constant WETH_PRICE_FEED   = 0xa767f745331D267c7751297D982b050c93985627;
    address public constant WSTETH            = ;
    address public constant WSTETH_PRICE_FEED = ;
    address public constant GNO               = ;
    address public constant GNO_PRICE_FEED    = 0x22441d81416430A54336aB28765abd31a792Ad37;

    function newListings() public view virtual returns (IEngine.Listing[] memory) {
        IEngine.Listing[] memory listings = new IEngine.Listing[](4);

        // wxDAI
        listings[0] = IEngine.Listing({
            asset:              RETH,
            assetSymbol:        'rETH',
            priceFeed:          RETH_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(45_00),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            _bpsToRay(7_00),
                variableRateSlope2:            _bpsToRay(300_00),
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
            ltv:                   68_50,
            liqThreshold:          79_50,
            liqBonus:              7_00,
            reserveFactor:         15_00,
            supplyCap:             20_000,
            borrowCap:             2_400,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         1
        });

        return listings;
    }

}
