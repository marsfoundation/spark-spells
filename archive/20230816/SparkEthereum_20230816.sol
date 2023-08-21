// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags } from '../../SparkPayloadEthereum.sol';

import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title  August 18, 2023 Spark Ethereum Proposal - Update to Aave 3.0.2, Unfreeze sDAI Market, Update DAI Interest Rate Strategy
 * @author Phoenix Labs
 * @dev    This proposal upgrades the pool contract implementation to Aave 3.0.2
 * Forum:  https://forum.makerdao.com/t/phoenix-labs-proposed-changes-for-spark-for-august-18th-spell/21612
 * Vote:   N/A
 */
contract SparkEthereum_20230816 is SparkPayloadEthereum {

    address public constant POOL_ADDRESS_PROVIDER      = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    address public constant POOL_IMPLEMENTATION        = 0x8115366Ca7Cf280a760f0bC0F6Db3026e2437115;
    address public constant DAI                        = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant sDAI                       = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address public constant DAI_INTEREST_RATE_STRATEGY = 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;

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
