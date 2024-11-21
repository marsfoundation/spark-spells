// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { SparkBaseTestBase } from 'src/SparkTestBase.sol';
import { Base }              from 'spark-address-registry/Base.sol';

import { RateLimitHelpers }  from 'spark-alm-controller/src/RateLimitHelpers.sol';
import { ForeignController } from 'spark-alm-controller/src/ForeignController.sol';
import { IRateLimits }       from 'spark-alm-controller/src/interfaces/IRateLimits.sol';


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
        assertEq(rateLimit.maxAmount, 84_211e18);
        assertEq(rateLimit.slope,     2_000_000e18 / uint256(1 days));

        executePayload(payload);

        _assertRateLimit(
            rateLimitKey,
            90_000_000e18,
            2_000_000e18 / uint256(1 days)
        );
    }
    
}
