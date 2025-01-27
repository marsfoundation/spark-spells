// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum }              from 'spark-address-registry/Ethereum.sol';
import { Base }                  from 'spark-address-registry/Base.sol';
import { MainnetController }     from 'spark-alm-controller/src/MainnetController.sol';
import { ForeignController }     from 'spark-alm-controller/src/ForeignController.sol';
import { IRateLimits }           from 'spark-alm-controller/src/interfaces/IRateLimits.sol';
import { RateLimitHelpers }      from 'spark-alm-controller/src/RateLimitHelpers.sol';
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { DataTypes }             from 'sparklend-v1-core/contracts/protocol/libraries/types/DataTypes.sol';

import { SparkTestBase } from 'src/SparkTestBase.sol';
import { ChainIdUtils }  from 'src/libraries/ChainId.sol';
import { ReserveConfig } from '../../ProtocolV3TestBase.sol';

contract SparkEthereum_20250206Test is SparkTestBase {
    using DomainHelpers for Domain;

    address public immutable MAINNET_FLUID_SUSDS_VAULT = 0x2BBE31d63E6813E3AC858C04dae43FB2a72B0D11;
    address public immutable BASE_FLUID_SUSDS_VAULT    = 0xf62e339f21d8018940f188F6987Bcdf02A849619;

    constructor() {
        id = '20250206';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock: 21717490,
            baseForkBlock:    25607987,
            gnosisForkBlock:  38037888
        });

        deployPayloads();
    }

    function test_ETHEREUM_SLL_FluidsUSDSOnboarding() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        uint256 depositAmount        = 1_000_000e18;

        deal(Ethereum.SUSDS, Ethereum.ALM_PROXY, 20 * depositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_DEPOSIT(),
            MAINNET_FLUID_SUSDS_VAULT
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_WITHDRAW(),
            MAINNET_FLUID_SUSDS_VAULT
        );

        vm.prank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/zero-maxAmount");
        controller.depositERC4626(MAINNET_FLUID_SUSDS_VAULT, depositAmount);

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, 10_000_000e18, uint256(5_000_000e18) / 1 days);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        vm.prank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.depositERC4626(MAINNET_FLUID_SUSDS_VAULT, 10_000_001e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  10_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.depositERC4626(MAINNET_FLUID_SUSDS_VAULT, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  10_000_000e18 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.withdrawERC4626(MAINNET_FLUID_SUSDS_VAULT, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  10_000_000e18 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        // Slope is 5M/day, the deposit amount of 1M should be replenished in a fifth of a day.
        // Wait for half of that, and assert half of the rate limit was replenished.
        skip(1 days / 10);
        assertApproxEqAbs(rateLimits.getCurrentRateLimit(depositKey), 10_000_000e18 - depositAmount/2, 5000);
        // Wait for 1 more second to avoid rounding issues
        skip(1 days / 10 + 1);
        assertEq(rateLimits.getCurrentRateLimit(depositKey), 10_000_000e18);
    }

    function test_ETHEREUM_Sparklend_WBTCLiquidationThreshold() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory wbtcConfig         = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold, 55_00);

        executeAllPayloadsAndBridges();

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        wbtcConfig.liquidationThreshold        = 50_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
    }

    function test_BASE_SLL_FluidsUSDSOnboardingSideEffects() public onChain(ChainIdUtils.Base()) {
        ForeignController controller = ForeignController(Base.ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Base.ALM_RATE_LIMITS);
        uint256 depositAmount        = 1_000_000e18;

        deal(Base.SUSDS, Base.ALM_PROXY, 20 * depositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_DEPOSIT(),
            BASE_FLUID_SUSDS_VAULT
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_WITHDRAW(),
            BASE_FLUID_SUSDS_VAULT
        );

        vm.prank(Base.ALM_RELAYER);
        vm.expectRevert("RateLimits/zero-maxAmount");
        controller.depositERC4626(BASE_FLUID_SUSDS_VAULT, depositAmount);

        executeAllPayloadsAndBridges();

        _assertRateLimit(depositKey, 10_000_000e18, uint256(5_000_000e18) / 1 days);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        vm.prank(Base.ALM_RELAYER);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.depositERC4626(BASE_FLUID_SUSDS_VAULT, 10_000_001e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  10_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Base.ALM_RELAYER);
        controller.depositERC4626(BASE_FLUID_SUSDS_VAULT, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  10_000_000e18 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Base.ALM_RELAYER);
        controller.withdrawERC4626(BASE_FLUID_SUSDS_VAULT, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  10_000_000e18 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        // Slope is 5M/day, the deposit amount of 1M should be replenished in a fifth of a day.
        // Wait for half of that, and assert half of the rate limit was replenished.
        skip(1 days / 10);
        assertApproxEqAbs(rateLimits.getCurrentRateLimit(depositKey), 10_000_000e18 - depositAmount/2, 5000);
        // Wait for 1 more second to avoid rounding issues
        skip(1 days / 10 + 1);
        assertEq(rateLimits.getCurrentRateLimit(depositKey), 10_000_000e18);
    }

    function test_BASE_SLL_FluidsUSDSRateLimits() public onChain(ChainIdUtils.Base()) {
        executeAllPayloadsAndBridges();
    }

    // TODO: question, is the timeout local to the USDC asset or global to the vault? 
    function test_BASE_IncreaseMorphoTimeout() public onChain(ChainIdUtils.Base()) {
        executeAllPayloadsAndBridges();
    }

}
