// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags } from '../../SparkPayloadEthereum.sol';

import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  August 16, 2023 Spark Ethereum Proposal - Update to Aave 3.0.2
 * @author Phoenix Labs
 * @dev    This proposal upgrades the pool contract implementation to Aave 3.0.2
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkEthereum_20230816 is SparkPayloadEthereum {

    address public constant POOL_ADDRESS_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    address public constant POOL_IMPLEMENTATION = 0x8115366Ca7Cf280a760f0bC0F6Db3026e2437115;

    function _postExecute() internal override {
        IPoolAddressesProvider(POOL_ADDRESS_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION);
    }

}
