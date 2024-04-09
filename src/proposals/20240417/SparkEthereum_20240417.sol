// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, Ethereum } from 'src/SparkPayloadEthereum.sol';

import { IACLManager }            from 'sparklend-v1-core/contracts/interfaces/IACLManager.sol';
import { IPoolAddressesProvider } from 'sparklend-v1-core/contracts/interfaces/IPoolAddressesProvider.sol';

import { ISparkLendFreezerMom } from 'sparklend-freezer/src/interfaces/ISparkLendFreezerMom.sol';

/**
 * @title  April 17, 2024 Spark Ethereum Proposal
 * @notice Upgrade Pool Implementation to SparkLend V1.0.0, activate Freezer Mom /w multi-sig, trigger Gnosis Payload.
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/apr-4-2024-proposed-changes-to-sparklend-for-upcoming-spell/24033
 *         TODO multisig link
 * Votes:  TODO
 */
contract SparkEthereum_20240417 is SparkPayloadEthereum {

    address public constant POOL_IMPLEMENTATION_NEW = 0x5aE329203E00f76891094DcfedD5Aca082a50e1b;
    address public constant FREEZER_MOM_NEW         = 0x237e3985dD7E373F2ec878EC1Ac48A228Cf2e7a3;
    address public constant FREEZER_MULTISIG        = 0x0;  // TODO

    function _postExecute()
        internal override
    {
        // Update Pool Implementation
        IPoolAddressesProvider(Ethereum.POOL_ADDRESSES_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION_NEW);

        // De-auth the old Freezer Mom
        IACLManager(ACL_MANAGER).removeEmergencyAdmin(Ethereum.FREEZER_MOM);
        IACLManager(ACL_MANAGER).removeRiskAdmin(Ethereum.FREEZER_MOM);

        // Activate the Freezer Mom
        ISparkLendFreezerMom(FREEZER_MOM).setAuthority(Ethereum.CHIEF);
        ISparkLendFreezerMom(FREEZER_MOM).rely(FREEZER_MULTISIG);
        IACLManager(ACL_MANAGER).addEmergencyAdmin(FREEZER_MOM_NEW);
        IACLManager(ACL_MANAGER).addRiskAdmin(FREEZER_MOM_NEW);

        // Trigger Gnosis Payload
    }

}
