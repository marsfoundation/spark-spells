// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { IALMProxy }         from "spark-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "spark-alm-controller/src/interfaces/IRateLimits.sol";
import { ForeignController } from "spark-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "spark-alm-controller/src/RateLimitHelpers.sol";

import { IExecutor } from "spark-gov-relay/src/interfaces/IExecutor.sol";

import { IPSM3 } from "spark-psm/src/interfaces/IPSM3.sol";

contract SparkBase_20241114Test is SparkBaseTestBase {

    address internal constant FREEZER = 0x90D8c80C028B4C09C0d8dcAab9bbB057F0513431;  // Gov. facilitator multisig
    address internal constant RELAYER = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

    address internal constant DEPLOYER = 0x6F3066538A648b9CFad0679DF0a7e40882A23AA4;

    constructor() {
        id = '20241114';
    }

    function setUp() public {
        vm.createSelectFork(getChain('base').rpcUrl, 22015320);  // Nov 5, 2024
        payload = deployPayload();
    }

    function testALMControllerDeployment() public {
        // Copied from the init library, but no harm checking this here
        IALMProxy         almProxy   = IALMProxy(Base.ALM_PROXY);
        IRateLimits       rateLimits = IRateLimits(Base.ALM_RATE_LIMITS);
        ForeignController controller = ForeignController(Base.ALM_CONTROLLER);

        assertEq(almProxy.hasRole(0x0,   Base.SPARK_EXECUTOR), true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Base.SPARK_EXECUTOR), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Base.SPARK_EXECUTOR), true, "incorrect-admin-controller");

        assertEq(almProxy.hasRole(0x0,   DEPLOYER), false, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, DEPLOYER), false, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, DEPLOYER), false, "incorrect-admin-controller");

        assertEq(address(controller.proxy()),      Base.ALM_PROXY,            "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), Base.ALM_RATE_LIMITS,      "incorrect-rateLimits");
        assertEq(address(controller.psm()),        Base.PSM3,                 "incorrect-psm");
        assertEq(address(controller.usdc()),       Base.USDC,                 "incorrect-usdc");
        assertEq(address(controller.cctp()),       Base.CCTP_TOKEN_MESSENGER, "incorrect-cctp");

        assertEq(controller.active(), true, "controller-not-active");
    }

    function testPSM3Deployment() public {
        // Copied from the init library, but no harm checking this here
        IPSM3 psm = IPSM3(Base.PSM3);

        // Verify that the shares are burned (IE owned by the zero address)
        assertGe(psm.shares(address(0)), 1e18, "psm-totalShares-not-seeded");

        assertEq(address(psm.usdc()),  Base.USDC,  "psm-incorrect-usdc");
        assertEq(address(psm.usds()),  Base.USDS,  "psm-incorrect-usds");
        assertEq(address(psm.susds()), Base.SUSDS, "psm-incorrect-susds");
    }

    function testALMControllerConfiguration() public {
        IALMProxy         almProxy   = IALMProxy(Base.ALM_PROXY);
        IRateLimits       rateLimits = IRateLimits(Base.ALM_RATE_LIMITS);
        ForeignController controller = ForeignController(Base.ALM_CONTROLLER);

        executePayload(payload);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), Base.ALM_CONTROLLER),     true, "incorrect-controller-almProxy");
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Base.ALM_CONTROLLER), true, "incorrect-controller-rateLimits");
        assertEq(controller.hasRole(controller.FREEZER(), FREEZER),                true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), RELAYER),                true, "incorrect-relayer-controller");

        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(controller.LIMIT_PSM_DEPOSIT(), Base.USDC),
            4_000_000e6,
            2_000_000e6 / uint256(1 days)
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(controller.LIMIT_PSM_WITHDRAW(), Base.USDC),
            7_000_000e6,
            2_000_000e6 / uint256(1 days)
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(controller.LIMIT_PSM_DEPOSIT(), Base.USDS),
            5_000_000e18,
            2_000_000e18 / uint256(1 days)
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(controller.LIMIT_PSM_WITHDRAW(), Base.USDS),
            type(uint256).max,
            0
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(controller.LIMIT_PSM_DEPOSIT(), Base.SUSDS),
            8_000_000e18,
            2_000_000e18 / uint256(1 days)
        );
        _assertRateLimit(
            RateLimitHelpers.makeAssetKey(controller.LIMIT_PSM_WITHDRAW(), Base.SUSDS),
            type(uint256).max,
            0
        );
        _assertRateLimit(
            controller.LIMIT_USDC_TO_CCTP(),
            type(uint256).max,
            0
        );
        _assertRateLimit(
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            4_000_000e6,
            2_000_000e6 / uint256(1 days)
        );

        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM), bytes32(uint256(uint160(Ethereum.ALM_PROXY))));
    }

    function testDelayAndGracePeriod() public {
        IExecutor executor = IExecutor(Base.SPARK_EXECUTOR);

        assertEq(executor.delay(),       100 seconds);
        assertEq(executor.gracePeriod(), 1000 seconds);

        executePayload(payload);

        assertEq(executor.delay(),       0);
        assertEq(executor.gracePeriod(), 12 hours);
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
