// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum, SparkPayloadEthereum, IEngine, Rates, EngineFlags } from 'src/SparkPayloadEthereum.sol';

import { ICapAutomator } from "lib/sparklend-cap-automator/src/interfaces/ICapAutomator.sol";

/**
 * @title  Sep 26, 2024 Spark Ethereum Proposal
 * @notice cbBTC Onboarding, WBTC Offboarding Parameters Update 1
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/sep-12-2024-proposed-changes-to-spark-for-upcoming-spell/25076
 *         http://forum.makerdao.com/t/wbtc-changes-and-risk-mitigation-10-august-2024/24844/26
 * Vote:   TODO
 */
contract SparkEthereum_20240926 is SparkPayloadEthereum {

    address internal constant CBBTC            = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant CBBTC_PRICE_FEED = 0x24C392CDbF32Cf911B258981a66d5541d85269ce;

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

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](1);

        updates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WBTC,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   70_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return updates;
    }

    function _postExecute()
        internal override
    {
        // cbBTC onboarding
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setSupplyCapConfig({asset: CBBTC, max: 3_000, gap: 500, increaseCooldown: 12 hours});
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setBorrowCapConfig({asset: CBBTC, max: 500, gap: 50, increaseCooldown: 12 hours});

        // WBTC offboarding
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setSupplyCapConfig({asset: Ethereum.WBTC, max: 5_000, gap: 200, increaseCooldown: 12 hours});
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setBorrowCapConfig({asset: Ethereum.WBTC, max: 1, gap: 1, increaseCooldown: 12 hours});

        // Making an initial deposit right after the listing to prevent spToken value manipulation
        IERC20(CBBTC).approve(address(LISTING_ENGINE.POOL()), 1e6);
        LISTING_ENGINE.POOL().deposit(CBBTC, 1e6, address(this), 0);
    }

}
