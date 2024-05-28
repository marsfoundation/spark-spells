// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IExecutorBase } from 'lib/spark-gov-relay/src/interfaces/IExecutorBase.sol';

import { SparkPayloadGnosis, Gnosis, IEngine, Rates, EngineFlags } from 'src/SparkPayloadGnosis.sol';

/**
 * @title  May 30, 2024 Spark Gnosis Proposal
 * @notice Turn off silo borrowing for USDC/USDC/EURe, update IRMs for XDAI/USDC/USDT/EURe/ETH, disable executor delay and min delay.
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/may-21-2024-proposed-changes-to-sparklend-for-upcoming-spell/24327
 * Votes:  https://vote.makerdao.com/polling/QmZhjzUg#poll-detail
 *         https://vote.makerdao.com/polling/QmT5e8NG#poll-detail
 *         https://vote.makerdao.com/polling/QmQHu69a#poll-detail
 */
contract SparkGnosis_20240530 is SparkPayloadGnosis {

    function borrowsUpdates() public pure override returns (IEngine.BorrowUpdate[] memory) {
        IEngine.BorrowUpdate[] memory updates = new IEngine.BorrowUpdate[](3);

        updates[0] = IEngine.BorrowUpdate({
            asset:                 Gnosis.USDC,
            enabledToBorrow:       EngineFlags.KEEP_CURRENT,
            flashloanable:         EngineFlags.KEEP_CURRENT,
            stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
            borrowableInIsolation: EngineFlags.KEEP_CURRENT,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            reserveFactor:         EngineFlags.KEEP_CURRENT
        });
        updates[1] = IEngine.BorrowUpdate({
            asset:                 Gnosis.USDT,
            enabledToBorrow:       EngineFlags.KEEP_CURRENT,
            flashloanable:         EngineFlags.KEEP_CURRENT,
            stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
            borrowableInIsolation: EngineFlags.KEEP_CURRENT,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            reserveFactor:         EngineFlags.KEEP_CURRENT
        });
        updates[2] = IEngine.BorrowUpdate({
            asset:                 Gnosis.EURE,
            enabledToBorrow:       EngineFlags.KEEP_CURRENT,
            flashloanable:         EngineFlags.KEEP_CURRENT,
            stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
            borrowableInIsolation: EngineFlags.KEEP_CURRENT,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            reserveFactor:         EngineFlags.KEEP_CURRENT
        });

        return updates;
    }

    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](5);

        // WETH
        Rates.RateStrategyParams memory wethParams = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(Gnosis.WETH);
        wethParams.optimalUsageRatio  = _bpsToRay(80_00);
        wethParams.variableRateSlope1 = _bpsToRay(2_50);
        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  Gnosis.WETH,
            params: wethParams
        });

        // DAI/USDC/USDT
        Rates.RateStrategyParams memory usdStablecoinParams = Rates.RateStrategyParams({
            optimalUsageRatio:             _bpsToRay(95_00),
            baseVariableBorrowRate:        _bpsToRay(0),
            variableRateSlope1:            _bpsToRay(9_00),
            variableRateSlope2:            _bpsToRay(15_00),
            stableRateSlope1:              0,
            stableRateSlope2:              0,
            baseStableRateOffset:          0,
            stableRateExcessOffset:        0,
            optimalStableToTotalDebtRatio: 0
        });
        ratesUpdate[1] = IEngine.RateStrategyUpdate({
            asset:  Gnosis.WXDAI,
            params: usdStablecoinParams
        });
        ratesUpdate[2] = IEngine.RateStrategyUpdate({
            asset:  Gnosis.USDC,
            params: usdStablecoinParams
        });
        ratesUpdate[3] = IEngine.RateStrategyUpdate({
            asset:  Gnosis.USDT,
            params: usdStablecoinParams
        });

        // EURe
        Rates.RateStrategyParams memory euroStablecoinParams = Rates.RateStrategyParams({
            optimalUsageRatio:             _bpsToRay(95_00),
            baseVariableBorrowRate:        _bpsToRay(0),
            variableRateSlope1:            _bpsToRay(5_00),
            variableRateSlope2:            _bpsToRay(15_00),
            stableRateSlope1:              0,
            stableRateSlope2:              0,
            baseStableRateOffset:          0,
            stableRateExcessOffset:        0,
            optimalStableToTotalDebtRatio: 0
        });
        ratesUpdate[4] = IEngine.RateStrategyUpdate({
            asset:  Gnosis.EURE,
            params: euroStablecoinParams
        });

        return ratesUpdate;
    }

    function _postExecute()
        internal override
    {
        IExecutorBase(address(this)).updateMinimumDelay(0);
        IExecutorBase(address(this)).updateDelay(0);
    }

}
