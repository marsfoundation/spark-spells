// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title  August 2, 2023 Spark Ethereum Proposal - Remove DAI Collateral and update WETH params.
 * @author Phoenix Labs
 * @dev    This proposal removes DAI as collateral and updates WETH reserve factor and
 *         interest rate strategy.
 *         TODO: Add links for forum and vote.
 */
contract SparkEthereum_20230802 is SparkPayloadEthereum {

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant DAI_INTEREST_RATE_STRATEGY = 0x191E97623B1733369290ee5d018d0B068bc0400D;

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
