// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, EngineFlags, IEngine, Rates } from 'src/SparkPayloadEthereum.sol';

import { ICapAutomator } from 'lib/sparklend-cap-automator/src/interfaces/ICapAutomator.sol';
import { IERC20 }        from 'lib/erc20-helpers/src/interfaces/IERC20.sol';

/**
 * @title  Jun 13, 2024 Spark Ethereum Proposal
 * @notice Onboard weETH
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/may-31-2024-proposed-changes-to-sparklend-for-upcoming-spell/24413
 * Votes:  TODO
 */
contract SparkEthereum_20240613 is SparkPayloadEthereum {

    address internal constant WEETH            = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant WEETH_PRICE_FEED = 0x1A6BDB22b9d7a454D20EAf12DB55D6B5F058183D;
    address internal constant CAP_AUTOMATOR    = 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef;

    function newListings()
        public pure override returns (IEngine.Listing[] memory)
    {
        IEngine.Listing[] memory listings = new IEngine.Listing[](1);

        listings[0] = IEngine.Listing({
            asset:              WEETH,
            assetSymbol:        'weETH',
            priceFeed:          WEETH_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(45_00),
                baseVariableBorrowRate:        _bpsToRay(5_00),
                variableRateSlope1:            _bpsToRay(15_00),
                variableRateSlope2:            _bpsToRay(300_00),
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
            flashloanable:         EngineFlags.DISABLED,
            ltv:                   72_00,
            liqThreshold:          73_00,
            liqBonus:              10_00,
            reserveFactor:         15_00,
            supplyCap:             5_000,
            borrowCap:             0,
            debtCeiling:           50_000_000,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        return listings;
    }

    function _postExecute()
        internal override
    {
        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: WEETH, max: 50_000, gap: 5_000, increaseCooldown: 12 hours});

        IERC20(WEETH).approve(address(LISTING_ENGINE.POOL()), 1_000_000);
        LISTING_ENGINE.POOL().deposit(WEETH, 1_000_000, address(this), 0);
    }

}
