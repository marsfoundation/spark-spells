// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { IRateLimits }       from "spark-alm-controller/src/interfaces/IRateLimits.sol";
import { ForeignController } from "spark-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "spark-alm-controller/src/RateLimitHelpers.sol";

contract SparkBase_20241107Test is SparkBaseTestBase {

    constructor() {
        id = '20241107';
    }

    function setUp() public {
        vm.createSelectFork(getChain('base').rpcUrl, 21752609);  // Oct 30, 2024
        payload = deployPayload();
    }

    function testALMControllerConfiguration() public {
        ForeignController c = ForeignController(Base.ALM_CONTROLLER);

        executePayload(payload);

        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(c.LIMIT_PSM_DEPOSIT(), Base.USDC),
            4_000_000e6,
            2_000_000e6 / uint256(1 days)
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(c.LIMIT_PSM_WITHDRAW(), Base.USDC),
            7_000_000e6,
            2_000_000e6 / uint256(1 days)
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(c.LIMIT_PSM_DEPOSIT(), Base.USDS),
            5_000_000e18,
            2_000_000e18 / uint256(1 days)
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(c.LIMIT_PSM_WITHDRAW(), Base.USDS),
            type(uint256).max,
            0
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(c.LIMIT_PSM_DEPOSIT(), Base.SUSDS),
            8_000_000e18,
            2_000_000e18 / uint256(1 days)
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(c.LIMIT_PSM_WITHDRAW(), Base.SUSDS),
            type(uint256).max,
            0
        );
        _assertRateLimit(c.LIMIT_USDC_TO_CCTP(), type(uint256).max, 0);
        _assertRateLimit(
            RateLimitHelpers.makeDomainKey(c.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            4_000_000e6,
            2_000_000e6 / uint256(1 days)
        );

        assertEq(c.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM), bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    }

    function _assertRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        IRateLimits.RateLimitData memory rateLimit = IRateLimits(Base.ALM_RATE_LIMITS).getRateLimitData(key);
        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  maxAmount);
        assertEq(rateLimit.lastUpdated, block.timestamp);
    }
    
}
