// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGnosis, IEngine, Rates, EngineFlags } from '../../SparkPayloadGnosis.sol';

/**
 * @title  November 15, 2023 Spark Gnosis Proposal - Update ETH interest rate model, raise wstETH supply cap to 10,000
 * @author Phoenix Labs
 * @dev    This proposal updates ETH variableRateSlope1 and updates wstETH supplyCap
 * Forum:       https://forum.makerdao.com/t/proposal-to-adjust-sparklend-parameters/22542
 * ETH Vote:    https://vote.makerdao.com/polling/QmQjKpbU
 * wstETH Vote: https://vote.makerdao.com/polling/QmaBLbxP
 */
contract SparkGnosis_20231115 is SparkPayloadGnosis {

    address public constant WSTETH = 0x6C76971f98945AE98dD7d4DFcA8711ebea946eA6;
    address public constant WETH   = 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);

        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     WSTETH,
            supplyCap: 10_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }
    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory weth = LISTING_ENGINE.RATE_STRATEGIES_FACTORY().getStrategyDataOfAsset(WETH);

        weth.baseVariableBorrowRate = 0;
        weth.variableRateSlope1     = _bpsToRay(3_20);

        ratesUpdate[0] = IEngine.RateStrategyUpdate({ asset: WETH, params: weth });

        return ratesUpdate;
    }

}
