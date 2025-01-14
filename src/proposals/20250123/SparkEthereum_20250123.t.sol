// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum }          from 'spark-address-registry/Ethereum.sol';
import { MainnetController } from 'spark-alm-controller/src/MainnetController.sol';
import { IRateLimits }       from 'spark-alm-controller/src/interfaces/IRateLimits.sol';
import { RateLimitHelpers }  from 'spark-alm-controller/src/RateLimitHelpers.sol';

import { SparkTestBase } from 'src/SparkTestBase.sol';
import { ChainIdUtils }  from 'src/libraries/ChainId.sol';

contract SparkEthereum_20250123Test is SparkTestBase {
    address constant public AAVE_PRIME_USDS_ATOKEN = 0x09AA30b182488f769a9824F15E6Ce58591Da4781;
    address constant public SPARKLEND_USDC_ATOKEN  = 0x377C3bd93f2a2984E1E7bE6A5C22c525eD4A4815;
    
    constructor() {
        id = '20250123';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock: 21623035,
            baseForkBlock:    25036049,
            gnosisForkBlock:  38037888
        });
        deployPayloads();
    }

    function test_ETHEREUM_Sparklend_USDSOnboarding() public onChain(ChainIdUtils.Ethereum()) {}

    function test_ETHEREUM_SLL_USDSRateLimits() public onChain(ChainIdUtils.Ethereum()) {}

    function test_ETHEREUM_SLL_USDCRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        uint256 depositAmount        = 5_000_000e6;
        deal(Ethereum.USDC, Ethereum.ALM_PROXY, 20 * depositAmount);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_DEPOSIT(),
            SPARKLEND_USDC_ATOKEN
        );

        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_WITHDRAW(),
            SPARKLEND_USDC_ATOKEN
        );

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  0);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), 0);
        vm.prank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/zero-maxAmount");
        controller.depositAave(SPARKLEND_USDC_ATOKEN, depositAmount);

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, 20_000_000e6, uint256(10_000_000e6) / 1 days);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        vm.prank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.depositAave(SPARKLEND_USDC_ATOKEN, 20_000_001e6);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  20_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.depositAave(SPARKLEND_USDC_ATOKEN, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  20_000_000e6 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.withdrawAave(SPARKLEND_USDC_ATOKEN, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  20_000_000e6 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        // slope is 10M/day, the deposit amount of 5M should be replenished in half a day.
        // we wait for half of that, and assert half of the rate limit was replenished.
        skip(1 days / 4);
        assertApproxEqAbs(rateLimits.getCurrentRateLimit(depositKey),  20_000_000e6 - depositAmount/2, 20000);
        // wait for 1 more second to avoid rounding issues
        skip(1 days / 4 + 1);
        assertEq(rateLimits.getCurrentRateLimit(depositKey),  20_000_000e6);
    }

    function test_ETHEREUM_SLL_PrimeAUSDSRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        uint256 depositAmount        = 5_000_000e18;
        deal(Ethereum.USDS, Ethereum.ALM_PROXY, 20*depositAmount);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_DEPOSIT(),
            AAVE_PRIME_USDS_ATOKEN
        );

        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_WITHDRAW(),
            AAVE_PRIME_USDS_ATOKEN
        );

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  0);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), 0);
        vm.prank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/zero-maxAmount");
        controller.depositAave(AAVE_PRIME_USDS_ATOKEN, depositAmount);

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, 50_000_000e18, uint256(50_000_000e18) / 1 days);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        vm.prank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.depositAave(AAVE_PRIME_USDS_ATOKEN, 50_000_001e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  50_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.depositAave(AAVE_PRIME_USDS_ATOKEN, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  50_000_000e18 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.withdrawAave(AAVE_PRIME_USDS_ATOKEN, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  50_000_000e18 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        // slope is 50M/day, the deposit amount of 5M should be replenished in a tenth of a day.
        // we wait for half of that, and assert half of the rate limit was replenished.
        skip(1 days / 20);
        assertApproxEqAbs(rateLimits.getCurrentRateLimit(depositKey),  50_000_000e18 - depositAmount/2, 5000);
        // wait for 1 more second to avoid rounding issues
        skip(1 days / 20 + 1);
        assertEq(rateLimits.getCurrentRateLimit(depositKey),  50_000_000e18);
    }
}
