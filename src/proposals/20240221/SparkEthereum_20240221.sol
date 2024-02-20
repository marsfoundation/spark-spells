// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title  February 21, 2024 Spark Ethereum Proposal - Increase DAI IRM spread, increase wstETH supply cap
 * @author Phoenix Labs
 * @dev    This proposal sets increases the DAI IRM spread to 6.7% and increases the wstETH supply cap
 * Forum: https://forum.makerdao.com/t/stability-scope-parameter-changes-9/23688
 * Forum: https://forum.makerdao.com/t/feb-14-2024-proposed-changes-to-sparklend-for-upcoming-spell/23684
 * Vote:  https://vote.makerdao.com/polling/QmQC1UXZ#poll-detail
 */
contract SparkEthereum_20240221 is SparkPayloadEthereum {

    address public constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    // Formula for 6.7% target APY:
    // bc -l <<< 'scale=27; (e( l(1.067)/(60 * 60 * 24 * 365) ) - 1) * 60 * 60 * 24 * 365 - 0.048790164207174267760128000'
    address public constant DAI_IRM = 0x3C4B090b5b479402e2270C66461D6a62B2054198;

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);
        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     WSTETH,
            supplyCap: 1_200_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

    function _postExecute()
        internal override
    {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_IRM
        );
    }

}
