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

    function testSUSDSRateLimit() public {
        ForeignController controller = ForeignController(Base.ALM_CONTROLLER);
        bytes32 rateLimitKey         = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_PSM_DEPOSIT(),
            Base.SUSDS
        );

        IRateLimits.RateLimitData memory rateLimit = IRateLimits(Base.ALM_RATE_LIMITS).getRateLimitData(rateLimitKey);
        assertEq(rateLimit.maxAmount, 8_000_000e18);
        assertEq(rateLimit.slope,     2_000_000e18 / uint256(1 days));

        executePayload(payload);

        _assertRateLimit(
            rateLimitKey,
            98_000_000e18,
            2_000_000e18 / uint256(1 days)
        );
    }

    function testSUSDSRateLimitSideEffects() public {
        ForeignController controller    = ForeignController(Base.ALM_CONTROLLER);
        address relayer                 = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;
        uint256 newRateLimit            = 98_000_000e18;
        uint256 amountAboveOldRateLimit = 10_000_000e18;
        uint256 amountAboveNewRateLimit = 100_000_000e18;
        bytes32 rateLimitKey            = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_PSM_DEPOSIT(),
            Base.SUSDS
        );
        deal(Base.SUSDS, Base.ALM_PROXY, amountAboveNewRateLimit);

        IRateLimits.RateLimitData memory rateLimit = IRateLimits(Base.ALM_RATE_LIMITS).getRateLimitData(rateLimitKey);
        assertEq(rateLimit.lastAmount, 84_211e18);

        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.depositPSM(Base.SUSDS, amountAboveOldRateLimit);

        executePayload(payload);

        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.depositPSM(Base.SUSDS, amountAboveNewRateLimit);

        vm.prank(relayer);
        controller.depositPSM(Base.SUSDS, amountAboveOldRateLimit);

        rateLimit = IRateLimits(Base.ALM_RATE_LIMITS).getRateLimitData(rateLimitKey);
        assertEq(rateLimit.maxAmount, newRateLimit);
        assertEq(rateLimit.lastAmount, newRateLimit - amountAboveOldRateLimit);
        assertEq(rateLimit.lastUpdated, block.timestamp);
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
