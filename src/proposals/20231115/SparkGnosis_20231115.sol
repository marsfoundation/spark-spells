// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGnosis, IEngine, Rates, EngineFlags } from '../../SparkPayloadGnosis.sol';

/**
 * @title  November 15, 2023 Spark Gnosis Proposal -
 * @author Phoenix Labs
 * @dev
 * Forum:
 * Vote:
 */
contract SparkGnosis_20231115 is SparkPayloadGnosis {

    address public constant WSTETH = 0x6C76971f98945AE98dD7d4DFcA8711ebea946eA6;

    uint256 public constant NEW_WSTETH_SUPPLY_CAP = 10_000;

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);

        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     WSTETH,
            supplyCap: NEW_WSTETH_SUPPLY_CAP,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

}
