// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IMetaMorpho, MarketParams } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';

import { Ethereum, SparkPayloadEthereum } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  Jul 25, 2024 Spark Ethereum Proposal
 * @notice Activate a Morpho Market for Pendle PT sUSDe
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/jul-12-2024-proposed-changes-to-spark-for-upcoming-spell/24635
 * Vote:   https://vote.makerdao.com/polling/QmWCBwtq
 */
contract SparkEthereum_20240725 is SparkPayloadEthereum {

    address internal constant PT_SUSDE_24OCT2024 = 0xAE5099C39f023C91d3dd55244CAFB36225B0850E;

    function _postExecute()
        internal override
    {
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_24OCT2024,
                oracle:          Ethereum.MORPHO_USDE_ORACLE,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.86e18
            }),
            100_000_000e18
        );
    }
}
