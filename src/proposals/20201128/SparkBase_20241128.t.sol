// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { SparkBaseTestBase } from 'src/SparkTestBase.sol';
import { Base }              from 'spark-address-registry/Base.sol';

import { RateLimitHelpers }  from 'spark-alm-controller/src/RateLimitHelpers.sol';
import { ForeignController } from 'spark-alm-controller/src/ForeignController.sol';
import { IRateLimits }       from 'spark-alm-controller/src/interfaces/IRateLimits.sol';

import { IExecutor } from 'spark-gov-relay/src/interfaces/IExecutor.sol';

contract SparkBase_20241128Test is SparkBaseTestBase {

    constructor() {
        id = '20241128';
    }

    function setUp() public {
        vm.createSelectFork(getChain('base').rpcUrl, 22704789);  // Nov 21, 2024
        payload = deployPayload();
    }

    function testExecutorParams() public {
      IExecutor executor = IExecutor(Base.SPARK_EXECUTOR);

      assertEq(executor.delay(),       100);
      assertEq(executor.gracePeriod(), 1000);

      executePayload(payload);

      assertEq(executor.delay(),       0);
      assertEq(executor.gracePeriod(), 7 days);
    }
}
