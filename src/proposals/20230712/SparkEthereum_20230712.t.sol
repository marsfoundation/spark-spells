// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';

import { TestWithExecutor } from 'aave-helpers/GovHelpers.sol';
import { IPool } from "aave-v3-core/contracts/interfaces/IPool.sol";

import { SparkTestBase, ReserveConfig } from '../../SparkTestBase.sol';
import { SparkEthereum_20230712 } from './SparkEthereum_20230712.sol';

contract SparkEthereum_20230712Test is SparkTestBase, TestWithExecutor {

    SparkEthereum_20230712 internal payload;

    address internal constant EXECUTOR = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    IPool internal constant POOL       = IPool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
    address internal constant SDAI     = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);

        _selectPayloadExecutor(EXECUTOR);

        payload = new SparkEthereum_20230712();
    }

    function testSpellExecution() public {
        ReserveConfig[] memory configsBefore = _getReservesConfigs(POOL);
        createConfigurationSnapshot('pre-Spark-Ethereum-sDAI-Freeze', POOL);

        _executePayload(address(payload));

        ReserveConfig[] memory configsAfter = _getReservesConfigs(POOL);
        createConfigurationSnapshot('post-Spark-Ethereum-sDAI-Freeze', POOL);

        assertEq(_findReserveConfig(configsBefore, SDAI).isFrozen, false);
        assertEq(_findReserveConfig(configsAfter, SDAI).isFrozen, true);
        _noReservesConfigsChangesApartFrom(
            configsBefore,
            configsAfter,
            SDAI
        );

        diffReports(
            'pre-Spark-Ethereum-sDAI-Freeze',
            'post-Spark-Ethereum-sDAI-Freeze'
        );
    }

}
