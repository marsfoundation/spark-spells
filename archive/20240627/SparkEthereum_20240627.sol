// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IMetaMorpho, MarketParams } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';
import { Gnosis }                    from 'lib/spark-address-registry/src/Gnosis.sol';
import { XChainForwarders }          from 'lib/xchain-helpers/src/XChainForwarders.sol';

import { SparkPayloadEthereum, Ethereum } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  June 27, 2024 Spark Ethereum Proposal
 * @notice Update Morpho supply caps, trigger Gnosis payload
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/jun-12-2024-proposed-changes-to-sparklend-for-upcoming-spell/24489
 * Votes:  https://vote.makerdao.com/polling/QmQv9zQR
 *         https://vote.makerdao.com/polling/QmU6KSGc
 *         https://vote.makerdao.com/polling/QmdQYTQe
 */
contract SparkEthereum_20240627 is SparkPayloadEthereum {
    address public constant GNOSIS_PAYLOAD = 0xd5A8d293Ce8B31123C285d55d0232b3C31c4D217;

    function _postExecute()
        internal override
    {
        // Morpho Vault Supply Cap Changes
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: Ethereum.SUSDE,
                oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.86e18
            }),
            500_000_000e18
        );
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: Ethereum.SUSDE,
                oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            200_000_000e18
        );

        // Trigger Gnosis Payload
        XChainForwarders.sendMessageGnosis(
            Gnosis.AMB_EXECUTOR,
            encodePayloadQueue(GNOSIS_PAYLOAD),
            4_000_000
        );
    }

}
