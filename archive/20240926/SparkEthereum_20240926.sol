// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum, SparkPayloadEthereum, IEngine, Rates, EngineFlags } from 'src/SparkPayloadEthereum.sol';

import { ICapAutomator } from "lib/sparklend-cap-automator/src/interfaces/ICapAutomator.sol";

/**
 * @title  Sep 26, 2024 Spark Ethereum Proposal
 * @notice cbBTC Onboarding
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/sep-12-2024-proposed-changes-to-spark-for-upcoming-spell/25076
 * Vote:   https://vote.makerdao.com/polling/QmPFkXna#poll-detail
 */
contract SparkEthereum_20240926 is SparkPayloadEthereum {

    address internal constant CBBTC            = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant CBBTC_PRICE_FEED = 0xb9ED698c9569c5abea716D1E64c089610a3768B6;

    function newListings()
        public pure override returns (IEngine.Listing[] memory)
    {
        IEngine.Listing[] memory listings = new IEngine.Listing[](1);

        listings[0] = IEngine.Listing({
            asset:              CBBTC,
            assetSymbol:        'cbBTC',
            priceFeed:          CBBTC_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(60_00),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            _bpsToRay(4_00),
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
            ltv:                   65_00,
            liqThreshold:          70_00,
            liqBonus:              8_00,
            reserveFactor:         20_00,
            supplyCap:             500,
            borrowCap:             50,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        return listings;
    }

    function _postExecute() internal override {
        // cbBTC onboarding
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setSupplyCapConfig({
            asset: CBBTC,
            max: 3_000,
            gap: 500,
            increaseCooldown: 12 hours
        });
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setBorrowCapConfig({
            asset: CBBTC,
            max: 500,
            gap: 50,
            increaseCooldown: 12 hours
        });

        // Making an initial deposit right after the listing to prevent spToken value manipulation
        IERC20(CBBTC).approve(address(LISTING_ENGINE.POOL()), 1e6);
        LISTING_ENGINE.POOL().deposit(CBBTC, 1e6, address(this), 0);
    }

}
