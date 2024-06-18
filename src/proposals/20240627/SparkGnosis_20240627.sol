// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IERC20 }        from 'lib/erc20-helpers/src/interfaces/IERC20.sol';
import { IExecutorBase } from 'lib/spark-gov-relay/src/interfaces/IExecutorBase.sol';

import { SparkPayloadGnosis, Gnosis, IEngine, Rates, EngineFlags } from 'src/SparkPayloadGnosis.sol';

/**
 * @title  June 27, 2024 Spark Gnosis Proposal
 * @notice Onboard USDC.e market and update USDC market parameters
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/jun-12-2024-proposed-changes-to-sparklend-for-upcoming-spell/24489
 * Votes:  https://vote.makerdao.com/polling/QmQv9zQR
 *         https://vote.makerdao.com/polling/QmU6KSGc
 *         https://vote.makerdao.com/polling/QmdQYTQe
 */
contract SparkGnosis_20240627 is SparkPayloadGnosis {

    address public constant USDCE            = 0x2a22f9c3b484c3629090FeED35F17Ff8F88f76F0;
    address public constant USDCE_PRICE_FEED = 0x6FC2871B6d9A94866B7260896257Fd5b50c09900;

    function newListings()
        public view override returns (IEngine.Listing[] memory)
    {
        IEngine.Listing[] memory listings = new IEngine.Listing[](1);

        listings[0] = IEngine.Listing({
            asset:              USDCE,
            assetSymbol:        'USDC.e',
            priceFeed:          USDCE_PRICE_FEED,
            rateStrategyParams: Rates.RateStrategyParams({
                optimalUsageRatio:             _bpsToRay(95_00),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            _bpsToRay(9_00),
                variableRateSlope2:            _bpsToRay(15_00),
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
            ltv:                   0,
            liqThreshold:          0,
            liqBonus:              0,
            reserveFactor:         10_00,
            supplyCap:             10_000_000,
            borrowCap:             8_000_000,
            debtCeiling:           0,
            liqProtocolFee:        0,
            eModeCategory:         0
        });

        return listings;
    }

    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory usdcParams = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(Gnosis.USDC);
        usdcParams.optimalUsageRatio  = _bpsToRay(80_00);
        usdcParams.variableRateSlope2 = _bpsToRay(50_00);
        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  Gnosis.USDC,
            params: usdcParams
        });

        return ratesUpdate;
    }

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);

        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     Gnosis.USDC,
            supplyCap: EngineFlags.KEEP_CURRENT,
            borrowCap: 1_000_000
        });

        return capsUpdate;
    }

    function _postExecute()
        internal override
    {
        // Making an initial deposit right after the listing to prevent spToken value manipulation
        IERC20(USDCE).approve(address(LISTING_ENGINE.POOL()), 1e6);
        LISTING_ENGINE.POOL().deposit(USDCE, 1e6, address(this), 0);
    }

}
