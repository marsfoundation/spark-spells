// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, Ethereum } from 'src/SparkPayloadEthereum.sol';

import { Gnosis } from 'spark-address-registry/src/Gnosis.sol';

import { IACLManager }            from 'sparklend-v1-core/contracts/interfaces/IACLManager.sol';
import { IPoolAddressesProvider } from 'sparklend-v1-core/contracts/interfaces/IPoolAddressesProvider.sol';

import { ISparkLendFreezerMom } from 'sparklend-freezer/interfaces/ISparkLendFreezerMom.sol';

import { XChainForwarders } from 'xchain-helpers/XChainForwarders.sol';

/**
 * @title  April 17, 2024 Spark Ethereum Proposal
 * @notice Upgrade Pool Implementation to SparkLend V1.0.0, activate Freezer Mom /w multi-sig, trigger Gnosis Payload.
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/apr-4-2024-proposed-changes-to-sparklend-for-upcoming-spell/24033
 *         https://forum.makerdao.com/t/sparklend-external-security-access-multisig-for-freezer-mom/24070
 * Votes:  https://vote.makerdao.com/polling/QmZND8WW#poll-detail
 *         https://vote.makerdao.com/polling/QmVXriiT#poll-detail
 */
contract SparkEthereum_20240417 is SparkPayloadEthereum {

    address public constant POOL_IMPLEMENTATION_NEW = 0x5aE329203E00f76891094DcfedD5Aca082a50e1b;
    address public constant FREEZER_MOM_NEW         = 0x237e3985dD7E373F2ec878EC1Ac48A228Cf2e7a3;
    address public constant FREEZER_MULTISIG        = 0x44efFc473e81632B12486866AA1678edbb7BEeC3;
    
    address public constant GNOSIS_PAYLOAD = 0xa2915822472377C7EF913D5E4D149891FEe4999e;

    function _postExecute()
        internal override
    {
        // Update Pool Implementation
        IPoolAddressesProvider(Ethereum.POOL_ADDRESSES_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION_NEW);

        // De-auth the old Freezer Mom
        IACLManager(Ethereum.ACL_MANAGER).removeEmergencyAdmin(Ethereum.FREEZER_MOM);
        IACLManager(Ethereum.ACL_MANAGER).removeRiskAdmin(Ethereum.FREEZER_MOM);

        // Activate the Freezer Mom
        ISparkLendFreezerMom(FREEZER_MOM_NEW).setAuthority(Ethereum.CHIEF);
        ISparkLendFreezerMom(FREEZER_MOM_NEW).rely(FREEZER_MULTISIG);
        IACLManager(Ethereum.ACL_MANAGER).addEmergencyAdmin(FREEZER_MOM_NEW);
        IACLManager(Ethereum.ACL_MANAGER).addRiskAdmin(FREEZER_MOM_NEW);

        // Trigger Gnosis Payload
        XChainForwarders.sendMessageGnosis(
            Gnosis.AMB_EXECUTOR,
            encodePayloadQueue(GNOSIS_PAYLOAD),
            4_000_000
        );
    }

}
