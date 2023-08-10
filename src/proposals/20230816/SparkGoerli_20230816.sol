// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGoerli, IEngine, Rates, EngineFlags } from '../../SparkPayloadGoerli.sol';

import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  August 18, 2023 Spark Goerli Proposal - Update to Aave 3.0.2, Unfreeze sDAI Market, Update DAI Interest Rate Strategy
 * @author Phoenix Labs
 * @dev    This proposal upgrades the pool contract implementation to Aave 3.0.2
 * Forum:  https://forum.makerdao.com/t/phoenix-labs-proposed-changes-for-spark-for-august-18th-spell/21612
 * Vote:   TODO
 */
contract SparkGoerli_20230816 is SparkPayloadGoerli {

    address public constant POOL_ADDRESS_PROVIDER      = 0x026a5B6114431d8F3eF2fA0E1B2EDdDccA9c540E;
    address public constant POOL_IMPLEMENTATION        = 0xe7EA57b22D5F496BF9Ca50a7830547b704Ecb91F;
    address public constant DAI                        = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
    address public constant sDAI                       = 0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C;
    address public constant DAI_INTEREST_RATE_STRATEGY = 0x70659BcA22A2a8BB324A526a8BB919185d3ecEBC;

    function _postExecute() internal override {
        // Update to Aave 3.0.2 for Pool implementation
        IPoolAddressesProvider(POOL_ADDRESS_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION);

        // Unfreeze sDAI market
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveFreeze(
            sDAI,
            false
        );

        // Update DAI market interest rate strategy to the one that tracks the DSR
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_INTEREST_RATE_STRATEGY
        );
    }

}
