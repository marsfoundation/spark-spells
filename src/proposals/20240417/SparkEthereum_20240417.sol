// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, Ethereum } from 'src/SparkPayloadEthereum.sol';

import { IPoolAddressesProvider } from 'sparklend-v1-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  April 17, 2024 Spark Ethereum Proposal
 * @notice Upgrade Pool Implementation to SparkLend V1.0.0, activate Freezer Mom /w multi-sig, trigger Gnosis Payload.
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/apr-4-2024-proposed-changes-to-sparklend-for-upcoming-spell/24033
 *         TODO multisig link
 * Votes:  TODO
 */
contract SparkEthereum_20240417 is SparkPayloadEthereum {

    address public constant POOL_IMPLEMENTATION = 0x5aE329203E00f76891094DcfedD5Aca082a50e1b;

    function _postExecute()
        internal override
    {
        IPoolAddressesProvider(Ethereum.POOL_ADDRESSES_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION);
    }

}
