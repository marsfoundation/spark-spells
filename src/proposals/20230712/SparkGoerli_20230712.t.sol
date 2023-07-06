// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';

import { TestWithExecutor } from 'aave-helpers/GovHelpers.sol';
import { IPool } from "aave-v3-core/contracts/interfaces/IPool.sol";
import { IERC20WithPermit } from "aave-v3-core/contracts/interfaces/IERC20WithPermit.sol";

import { SparkTestBase, ReserveConfig } from '../../SparkTestBase.sol';
import { SparkGoerli_20230712 } from './SparkGoerli_20230712.sol';

contract SparkGoerli_20230712Test is SparkTestBase, TestWithExecutor {

    SparkGoerli_20230712 internal payload;

    address internal constant EXECUTOR = 0x4e847915D8a9f2Ab0cDf2FC2FD0A30428F25665d;
    IPool internal constant POOL       = IPool(0x26ca51Af4506DE7a6f0785D20CD776081a05fF6d);
    address internal constant SDAI     = 0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C;

    function setUp() public {
        vm.createSelectFork(getChain('goerli').rpcUrl, 9300769);

        _selectPayloadExecutor(EXECUTOR);

        payload = SparkGoerli_20230712(0x2Ad00613A66D71Ff2B0607fB3C4632C47a50DADe);
    }

    function testSpellExecution() public {
        ReserveConfig[] memory configsBefore = _getReservesConfigs(POOL);
        createConfigurationSnapshot('pre-Spark-Goerli-sDAI-Freeze', POOL);

        _executePayload(address(payload));

        ReserveConfig[] memory configsAfter = _getReservesConfigs(POOL);
        createConfigurationSnapshot('post-Spark-Goerli-sDAI-Freeze', POOL);

        assertEq(_findReserveConfig(configsBefore, SDAI).isFrozen, false);
        assertEq(_findReserveConfig(configsAfter, SDAI).isFrozen, true);
        _noReservesConfigsChangesApartFrom(
            configsBefore,
            configsAfter,
            SDAI
        );
    }

    function testCantSupply() public {
        _executePayload(address(payload));

        deal(SDAI, address(this), 1 ether);
        IERC20WithPermit(SDAI).approve(address(POOL), 1 ether);
        vm.expectRevert(bytes('28'));      // Frozen
        POOL.supply(SDAI, 1 ether, address(this), 0);
    }

}
