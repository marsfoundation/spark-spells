// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Ethereum, SparkPayloadEthereum, IEngine, EngineFlags } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  Nov 28, 2024 Spark Ethereum Proposal
 * @notice Sparklend: update WBTC and cbBTC parameters
 *         Morpho: onboard PT-USDe-27Mar2025 and increase PT-sUSDe-27Mar2025 cap
 *         DDM: increase AAVE lido's line
 * @author Wonderland
 * Forum:  https://forum.sky.money/t/28-nov-2024-proposed-changes-to-spark-for-upcoming-spell/25543/2
 */
contract SparkEthereum_20241128 is SparkPayloadEthereum {

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
        // Reduce LT from 65% to 60%
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](1);
        updates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WBTC,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   60_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });
        return updates;
    }
}
