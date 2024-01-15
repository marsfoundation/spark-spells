// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags, Address } from '../../SparkPayloadEthereum.sol';

/**
 * @title  January 24, 2024 Spark Ethereum Proposal - Raise WBTC supply cap
 * @author Phoenix Labs
 * @dev This proposal sets WBTC supplyCap
 * Forum:     TBA
 * WBTC Vote: TBA
 */
contract SparkEthereum_20241024 is SparkPayloadEthereum {

    using Address for address;

    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);
        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     WBTC,
            supplyCap: 5_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

}
