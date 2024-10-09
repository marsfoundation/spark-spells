// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum, SparkPayloadEthereum, IEngine, Rates, EngineFlags } from 'src/SparkPayloadEthereum.sol';

import { ICapAutomator } from "lib/sparklend-cap-automator/src/interfaces/ICapAutomator.sol";

import { IMetaMorpho, MarketParams } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';

/**
 * @title  Oct 17, 2024 Spark Ethereum Proposal
 * @notice onboard sUSDS
 *         Update Oracle for sDAI
 *         Onboard Pendle sUSDe PTs to Morpho Spark DAI Vault
 *         WBTC Changes
 * @author Phoenix Labs
 * Forum:  https://forum.sky.money/t/oct-3-2024-proposed-changes-to-spark-for-upcoming-spell/25293
 * Vote:   https://vote.makerdao.com/polling/QmbHaA2G
 *         https://vote.makerdao.com/polling/QmShWccA
 *         https://vote.makerdao.com/polling/QmTksxrr
 *         https://vote.makerdao.com/polling/QmSiQVWm
 */
contract SparkEthereum_20241017 is SparkPayloadEthereum {

    address internal constant SUSDS            = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant SUSDS_PRICE_FEED = 0x27f3A665c75aFdf43CfbF6B3A859B698f46ef656;

    address internal constant SDAI_PRICE_FEED = 0x0c0864837C7e65458aCD3C665222203217019436;

    address internal constant PT_SUSDE_26DEC2024      = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;
    address internal constant PT_26DEC2024_PRICE_FEED = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address internal constant PT_SUSDE_27MAR2025      = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;
    address internal constant PT_27MAR2025_PRICE_FEED = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;

    function newListings()
        public pure override returns (IEngine.Listing[] memory)
    {
        IEngine.Listing[] memory listings = new IEngine.Listing[](1);

        listings[0] = IEngine.Listing({
            asset:              SUSDS,
            assetSymbol:        'sUSDS',
            priceFeed:          SUSDS_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(80_00),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            _bpsToRay(2_00),
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
            ltv:                   79_00,
            liqThreshold:          80_00,
            liqBonus:              5_00,
            reserveFactor:         10_00,
            supplyCap:             50_000_000,
            borrowCap:             0,
            debtCeiling:           0,
            liqProtocolFee:        10_00,
            eModeCategory:         0
        });

        return listings;
    }

    function priceFeedsUpdates() public pure override returns (IEngine.PriceFeedUpdate[] memory) {
        IEngine.PriceFeedUpdate[] memory updates = new IEngine.PriceFeedUpdate[](1);

        updates[0] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.SDAI,
            priceFeed: SDAI_PRICE_FEED
        });

        return updates;
    }

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
        // Reduce LT from 75% to 70%
        // Reduce liquidation protocol fee from 10% to 0%
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](1);
        updates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WBTC,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   70_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: 0,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });
        return updates;
    }

    function _postExecute() internal override {
        ICapAutomator capAutomator = ICapAutomator(Ethereum.CAP_AUTOMATOR);

        // sUSDS onboarding
        capAutomator.setSupplyCapConfig({
            asset: SUSDS,
            max: 500_000_000,
            gap: 50_000_000,
            increaseCooldown: 12 hours
        });

        // Making an initial deposit right after the listing to prevent spToken value manipulation
        IERC20(SUSDS).approve(address(LISTING_ENGINE.POOL()), 1e6);
        LISTING_ENGINE.POOL().deposit(SUSDS, 1e6, address(this), 0);

        // Onboard Pendle sUSDe PTs to Morpho Spark DAI Vault
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_26DEC2024,
                oracle:          PT_26DEC2024_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            100_000_000e18
        );

        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_27MAR2025,
                oracle:          PT_27MAR2025_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            100_000_000e18
        );

        // Reduce supply cap max from 10,000 WBTC to 5,000 WBTC
        // Reduce supply cap gap from 500 WBTC to 200 WBTC
        capAutomator.setSupplyCapConfig({
            asset: Ethereum.WBTC,
            max: 5_000,
            gap: 200,
            increaseCooldown: 12 hours
        });

        // Reduce borrow cap max from 2,000 WBTC to 1 WBTC
        // Reduce borrow cap gap from 100 WBTC to 1 WBTC
        capAutomator.setBorrowCapConfig({
            asset: Ethereum.WBTC,
            max: 1,
            gap: 1,
            increaseCooldown: 12 hours
        });
    }
}
