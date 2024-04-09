// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGnosis, Gnosis } from 'src/SparkPayloadGnosis.sol';

import { IPoolAddressesProvider } from 'sparklend-v1-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  April 17, 2024 Spark Gnosis Proposal
 * @notice Upgrade Pool Implementation to SparkLend V1.0.0, onboard sxDAI/EURe/USDC/USDT, parameter refresh.
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/apr-4-2024-proposed-changes-to-sparklend-for-upcoming-spell/24033
 * Votes:  TODO
 */
contract SparkGnosis_20240417 is SparkPayloadGnosis {

    address public constant POOL_IMPLEMENTATION_NEW = 0xCF86A65779e88bedfF0319FE13aE2B47358EB1bF;

    function _postExecute()
        internal override
    {
        // Update Pool Implementation
        IPoolAddressesProvider(Gnosis.POOL_ADDRESSES_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION_NEW);

        
    }

}
