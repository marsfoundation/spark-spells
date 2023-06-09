// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title List rETH on Spark Ethereum
 * @author Phoenix Labs
 * @dev This proposal lists rETH + updates DAI interest rate strategy on Spark Ethereum
 * Forum:        https://forum.makerdao.com/t/2023-05-24-spark-protocol-updates/20958
 * rETH Vote:    https://vote.makerdao.com/polling/QmeEV7ph#poll-detail
 * DAI IRS Vote: https://vote.makerdao.com/polling/QmWodV1J#poll-detail
 */
contract SparkEthereum_20230525 is SparkPayloadEthereum {

    address public constant RETH            = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant RETH_PRICE_FEED = 0x05225Cd708bCa9253789C1374e4337a019e99D56;

    address public constant DAI                        = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant DAI_INTEREST_RATE_STRATEGY = 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;

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
