// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { SparkPayloadGoerli, IEngine, Rates, EngineFlags } from '../../SparkPayloadGoerli.sol';

/**
 * @title List rETH on Spark Goerli
 * @author Phoenix Labs
 * @dev This proposal lists rETH + updates DAI interest rate strategy on Spark Goerli
 * Forum:        https://forum.makerdao.com/t/2023-05-24-spark-protocol-updates/20958
 * rETH Vote:    https://vote.makerdao.com/polling/QmeEV7ph#poll-detail
 * DAI IRS Vote: https://vote.makerdao.com/polling/QmWodV1J#poll-detail
 */
contract SparkGoerli_20230525 is SparkPayloadGoerli {

    address public constant RETH            = 0x62BC478FFC429161115A6E4090f819CE5C50A5d9;
    address public constant RETH_PRICE_FEED = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;   // Just use ETH / USD

    address public constant DAI                        = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
    address public constant DAI_INTEREST_RATE_STRATEGY = 0x70659BcA22A2a8BB324A526a8BB919185d3ecEBC;

    function newListings() public pure override returns (IEngine.Listing[] memory) {
        IEngine.Listing[] memory listings = new IEngine.Listing[](1);

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

    function _postExecute() internal override {
        // Update the DAI interest rate strategy
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_INTEREST_RATE_STRATEGY
        );
    }

}
