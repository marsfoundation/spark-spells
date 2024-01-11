// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGnosis } from '../../SparkPayloadGnosis.sol';

import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  January 10, 2024 Spark Gnosis Proposal
 * @author Phoenix Labs
 * @dev    Pool Impl Patch.
 */
contract SparkGnosis_20240110 is SparkPayloadGnosis {

    address public constant POOL_ADDRESS_PROVIDER = 0xA98DaCB3fC964A6A0d2ce3B77294241585EAbA6d;
    address public constant POOL_IMPLEMENTATION   = 0xa8fC41696F2a230b03F77d258Db39069e9e55F56;

    function _preExecute() internal override {
        // Hot fix for Jan 10th issue
        IPoolAddressesProvider(POOL_ADDRESS_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION);
        // Needs to be set back to 0 after implementation update
        LISTING_ENGINE.POOL_CONFIGURATOR().updateFlashloanPremiumTotal(
            0
        );
    }

}
