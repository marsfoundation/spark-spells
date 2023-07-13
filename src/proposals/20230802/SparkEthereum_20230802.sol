// SPDX-License-Identifier: AGPL-3.0
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
contract SparkEthereum_20230802 is SparkPayloadEthereum {

    address public constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address public constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
	address public constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

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

	function collateralsUpdates()
		public pure override returns (IEngine.CollateralUpdate[] memory)
	{
		IEngine.CollateralUpdate[] memory collateralUpdate = new IEngine.CollateralUpdate[](1);

		collateralUpdate[0] = IEngine.CollateralUpdate({
			asset:          DAI,
			ltv:            0,
			liqThreshold:   0,
			liqBonus:       0,
			debtCeiling:    0,
			liqProtocolFee: 0,
			eModeCategory:  EngineFlags.KEEP_CURRENT
		});

		return collateralUpdate;
	}

	function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory weth = LISTING_ENGINE
			.RATE_STRATEGIES_FACTORY()
			.getStrategyDataOfAsset(WETH);

		weth.variableRateSlope1 = _bpsToRay(4_00);

		ratesUpdate[0] = IEngine.RateStrategyUpdate({
			asset:  WETH,
			params: weth
        });

        return ratesUpdate;
    }

    function _postExecute() internal override {
		LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_INTEREST_RATE_STRATEGY
        );
    }

}
