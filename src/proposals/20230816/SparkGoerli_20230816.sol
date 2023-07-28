// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGoerli, IEngine, Rates, EngineFlags } from '../../SparkPayloadGoerli.sol';

import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  August 16, 2023 Spark Goerli Proposal - Update to Aave 3.0.2
 * @author Phoenix Labs
 * @dev    This proposal upgrades the pool contract implementation to Aave 3.0.2
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkGoerli_20230816 is SparkPayloadGoerli {

    address public constant POOL_ADDRESS_PROVIDER = 0x026a5B6114431d8F3eF2fA0E1B2EDdDccA9c540E;
    address public constant POOL_IMPLEMENTATION   = 0xe7EA57b22D5F496BF9Ca50a7830547b704Ecb91F;

    function _postExecute() internal override {
        IPoolAddressesProvider(POOL_ADDRESS_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION);
    }

}
