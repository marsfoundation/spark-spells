// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGoerli, IEngine, Rates, EngineFlags } from '../../SparkPayloadGoerli.sol';

/**
 * @title  August 2, 2023 Spark Goerli Proposal - Remove DAI Collateral and update WETH params.
 * @author Phoenix Labs
 * @dev    This proposal removes DAI as collateral and updates WETH reserve factor and
 *         interest rate strategy.
 *         TODO: Add links for forum and vote.
 */
contract SparkGoerli_20230802 is SparkPayloadGoerli {

    address public constant DAI  = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
    address public constant WETH = 0x7D5afF7ab67b431cDFA6A94d50d3124cC4AB2611;

    address public constant DAI_INTEREST_RATE_STRATEGY = 0x7f44e1c1dE70059D7cc483378BEFeE2a030CE247;

    function borrowsUpdates()
        public pure override returns (IEngine.BorrowUpdate[] memory)
    {
        IEngine.BorrowUpdate[] memory borrowsUpdate = new IEngine.BorrowUpdate[](1);

        borrowsUpdate[0] = IEngine.BorrowUpdate({
            asset:                 WETH,
            reserveFactor:         5_00,
            enabledToBorrow:       EngineFlags.KEEP_CURRENT,
            flashloanable:         EngineFlags.KEEP_CURRENT,
            stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
            borrowableInIsolation: EngineFlags.KEEP_CURRENT,
            withSiloedBorrowing:   EngineFlags.KEEP_CURRENT
        });

        return borrowsUpdate;
    }

    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory weth = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(WETH);

        weth.variableRateSlope1 = _bpsToRay(3_00);

        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  WETH,
            params: weth
        });

        return ratesUpdate;
    }

    function _postExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().configureReserveAsCollateral(DAI, 1_00, 1_00, 104_50);

        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_INTEREST_RATE_STRATEGY
        );
    }

}
