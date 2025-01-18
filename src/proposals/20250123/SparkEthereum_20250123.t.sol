// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;
import "forge-std/console.sol";

import { Ethereum }              from 'spark-address-registry/Ethereum.sol';
import { Base }                  from 'spark-address-registry/Base.sol';
import { MainnetController }     from 'spark-alm-controller/src/MainnetController.sol';
import { ForeignController }     from 'spark-alm-controller/src/ForeignController.sol';
import { IRateLimits }           from 'spark-alm-controller/src/interfaces/IRateLimits.sol';
import { RateLimitHelpers }      from 'spark-alm-controller/src/RateLimitHelpers.sol';
import { IERC20 }                from 'lib/erc20-helpers/src/interfaces/IERC20.sol';
import { CCTPForwarder }         from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { Errors }                from 'sparklend-v1-core/contracts/protocol/libraries/helpers/Errors.sol';
import { ReserveConfiguration }  from 'sparklend-v1-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import { DataTypes }             from 'sparklend-v1-core/contracts/protocol/libraries/types/DataTypes.sol';

import { SparkTestBase, InterestStrategyValues } from 'src/SparkTestBase.sol';
import { ChainIdUtils }                          from 'src/libraries/ChainId.sol';
import { ReserveConfig }                         from '../../ProtocolV3TestBase.sol';

interface IRMLike {
    function RATE_SOURCE() external view returns(address);
    function getBaseVariableBorrowRate() external view returns (uint256);
}

interface ISUSDS {
    function ssr() external view returns (uint256);
}

interface IXD {
    function RESERVE_TREASURY_ADDRESS() external returns (address);
}

contract SparkEthereum_20250123Test is SparkTestBase {
    using DomainHelpers for Domain;

    address constant public AAVE_PRIME_USDS_ATOKEN = 0x09AA30b182488f769a9824F15E6Ce58591Da4781;
    address constant public SPARKLEND_USDC_ATOKEN  = 0x377C3bd93f2a2984E1E7bE6A5C22c525eD4A4815;
    // Same source used on 2025-01-09
    address constant public SSR_RATE_SOURCE        = 0x57027B6262083E3aC3c8B2EB99f7e8005f669973;
    address constant public FIXED_1USD_ORACLE      = 0x42a03F81dd8A1cEcD746dc262e4d1CD9fD39F777;
    address constant public USDS_IRM               = 0x2DB2f1eE78b4e0ad5AaF44969E2E8f563437f34C;

    constructor() {
        id = '20250123';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock: 21651750,
            baseForkBlock:    25036049,
            gnosisForkBlock:  38037888
        });
        deployPayloads();

        chainSpellMetadata[ChainIdUtils.Ethereum()].domain.selectFork();
    }

    function test_ETHEREUM_Sparklend_USDSOnboarding() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        assertEq(allConfigsBefore.length, 12);

        uint256 ssrFromSUSDS = ISUSDS(Ethereum.SUSDS).ssr();
        // Sanity check: ssr matches reality
        assertEq(ssrFromSUSDS, 1.000000003734875566854894261e27);

        executeAllPayloadsAndBridges();
        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        IRMLike interestRateStrategy           = IRMLike(_findReserveConfigBySymbol(allConfigsAfter, 'USDS').interestRateStrategy);
        uint256 aprFromSUSDS                   = (ssrFromSUSDS - 1e27) * 365 days;

        assertEq(interestRateStrategy.RATE_SOURCE(),               SSR_RATE_SOURCE);
        assertEq(interestRateStrategy.getBaseVariableBorrowRate(), aprFromSUSDS + 0.0025e27);

        assertEq(allConfigsAfter.length, 13);
        ReserveConfig memory usds = ReserveConfig({
            symbol:                  'USDS',
            underlying:               Ethereum.USDS,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      0,
            liquidationThreshold:     0,
            liquidationBonus:         0,
            liquidationProtocolFee:   10_00,
            reserveFactor:            0,
            usageAsCollateralEnabled: false,
            borrowingEnabled:         true,
            interestRateStrategy:     address(interestRateStrategy),
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  true,
            isFlashloanable:          false,
            supplyCap:                0,
            borrowCap:                0,
            debtCeiling:              0,
            eModeCategory:            0
        });

        _validateReserveConfig(usds, allConfigsAfter);
        _validateInterestRateStrategy(
            address(interestRateStrategy),
            USDS_IRM,
            InterestStrategyValues({
                addressesProvider:             address(Ethereum.POOL_ADDRESSES_PROVIDER),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        aprFromSUSDS + 0.0025e27,
                variableRateSlope1:            0,
                variableRateSlope2:            0.2e27
            })
        );
    }

    function test_ETHEREUM_Sparklend_SparkProxyCanSeedNewMarket() public onChain(ChainIdUtils.Ethereum()) {
        assertGe(IERC20(Ethereum.USDS).balanceOf(Ethereum.SPARK_PROXY), 1e18);
    }

    function test_ETHEREUM_Sparklend_USDSOnboardingE2E() external onChain(ChainIdUtils.Ethereum()){
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        uint256 depositAmount    = 1_000_000e18; // USDS
        uint256 collateraAmount  = 200e18;     // Ether == 660_000e18 usds
        uint256 borrowAmount     = 500_000e18;   // USDS
        uint256 liquidatorAmount = 1000e18;   // USDS
        address liquidator       = makeAddr('liquidator');

        IERC20 usds  = IERC20(Ethereum.USDS);
        IERC20 weth  = IERC20(Ethereum.WETH);
        IERC20 aWETH = IERC20(pool.getReserveData(Ethereum.WETH).aTokenAddress);

        deal(Ethereum.USDS, address(this), depositAmount);
        deal(Ethereum.WETH, address(this), collateraAmount);
        deal(Ethereum.USDS, liquidator, liquidatorAmount); // amount is not relevant
        usds.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);
        vm.prank(liquidator);
        usds.approve(address(pool), type(uint256).max);

        vm.expectRevert(bytes('Contract 0x0000000000000000000000000000000000000000 does not exist and is not marked as persistent, see `vm.makePersistent()`'));
        pool.deposit(Ethereum.USDS, depositAmount, address(this), 0);

        executeAllPayloadsAndBridges();
        IERC20 aUSDS = IERC20(pool.getReserveData(Ethereum.USDS).aTokenAddress);

        assertEq(pool.getReserveData(Ethereum.USDS).accruedToTreasury, 0);
        // Seeded by spell
        assertEq(aUSDS.totalSupply(), 1e18);

        pool.deposit(Ethereum.USDS, depositAmount, address(this), 0);
        assertEq(
            aUSDS.totalSupply(),
            depositAmount + 1e18
        );

        // Ensure it can NOT be set as collateral
        vm.expectRevert(bytes(Errors.USER_IN_ISOLATION_MODE_OR_LTV_ZERO));
        pool.setUserUseReserveAsCollateral(Ethereum.USDS, true);

        // Add some other collateral
        pool.deposit(Ethereum.WETH, collateraAmount, address(this), 0);
        pool.setUserUseReserveAsCollateral(Ethereum.WETH, true);

        // Can NOT be borrowed in stable mode
        vm.expectRevert(bytes(Errors.STABLE_BORROWING_NOT_ENABLED));
        pool.borrow(Ethereum.USDS, borrowAmount, 1, 0, address(this));

        (,,,,, uint healthFactor) = pool.getUserAccountData(address(this)); 
        assertEq(healthFactor, type(uint256).max);
        // Can be borrowed in variable mode
        pool.borrow(Ethereum.USDS, borrowAmount, 2, 0, address(this));
        assertEq(usds.balanceOf(address(this)), borrowAmount);
        (,,,,, healthFactor) = pool.getUserAccountData(address(this)); 
        assertEq(healthFactor, 1.098626021244240000e18);

        // At current fork block, this returns 330911452182, 3.3k with 8 decimals.
        vm.mockCall(
            0x8105f69D9C41644c6A0803fDA7D03Aa70996cFD9, // oracle used for ETH
            abi.encodeWithSignature("getAssetPrice(address)", Ethereum.WETH),
            abi.encode(uint256(1_000e8)) // hard-code price to 1ETH == 1000 USDS
        );
        (,,,,, healthFactor) = pool.getUserAccountData(address(this)); 
        assertEq(healthFactor, 0.332000000000000000e18);

        assertEq(aUSDS.balanceOf(Ethereum.TREASURY), 0);
        assertEq(aWETH.balanceOf(Ethereum.TREASURY), 73.635960519566877739e18);
        assertEq(ReserveConfiguration.getLiquidationProtocolFee(DataTypes.ReserveConfigurationMap(pool.getConfiguration(Ethereum.WETH).data) ), 10_00);
        vm.prank(liquidator);
        pool.liquidationCall(Ethereum.WETH, Ethereum.USDS, address(this), liquidatorAmount, false);
        // Liquidator received 1 ETH collateral + 0.045 liquidation bonus for ETH
        assertEq(weth.balanceOf(liquidator), 1.045e18);
        // Treasury receives no USDS fees, regardless of debt token (USDS) settings,
        // and collateral (ETH) liquidationProtocolFee is used
        assertEq(aUSDS.balanceOf(Ethereum.TREASURY), 0);
        assertEq(aWETH.balanceOf(Ethereum.TREASURY), 73.640960519566877738e18);
    }

    function test_ETHEREUM_SLL_USDSRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        executeAllPayloadsAndBridges();
        address sparklendUSDSAtoken = pool.getReserveData(Ethereum.USDS).aTokenAddress;

        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        uint256 depositAmount        = 7_500_000e18;
        deal(Ethereum.USDS, Ethereum.ALM_PROXY, 20*depositAmount);
        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_DEPOSIT(),
            sparklendUSDSAtoken
        );
        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_WITHDRAW(),
            sparklendUSDSAtoken
        );

        _assertRateLimit(depositKey, 150_000_000e18, uint256(75_000_000e18) / 1 days);
        _assertRateLimit(withdrawKey, type(uint256).max, 0);

        vm.prank(Ethereum.ALM_RELAYER);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        controller.depositAave(sparklendUSDSAtoken, 150_000_001e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  150_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.depositAave(sparklendUSDSAtoken, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  150_000_000e18 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        vm.prank(Ethereum.ALM_RELAYER);
        controller.withdrawAave(sparklendUSDSAtoken, depositAmount);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  150_000_000e18 - depositAmount);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        // Slope is 75M/day, the deposit amount of 5M should be replenished in a tenth of a day.
        // Wait for half of that, and assert half of the rate limit was replenished.
        skip(1 days / 20);
        assertApproxEqAbs(rateLimits.getCurrentRateLimit(depositKey),  150_000_000e18 - depositAmount/2, 5000);
        // Wait for 1 more second to avoid rounding issues
        skip(1 days / 20 + 1);
        assertEq(rateLimits.getCurrentRateLimit(depositKey),  150_000_000e18);
    }

    function test_ETHEREUM_SLL_AmendmentRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        _assertRateLimit(
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            4_000_000e6,
            2_000_000e6 / uint256(1 days),
            376_388.876880e6,
            1737122807
        );
        _assertUnlimitedRateLimit(controller.LIMIT_USDC_TO_CCTP());

        executeAllPayloadsAndBridges();

        _assertRateLimit(controller.LIMIT_USDS_MINT(), 50_000_000e18, 50_000_000e18 / uint256(1 days));
        _assertRateLimit(controller.LIMIT_USDS_TO_USDC(), 50_000_000e6, 50_000_000e6 / uint256(1 days));
        _assertUnlimitedRateLimit(controller.LIMIT_USDC_TO_CCTP());
        _assertRateLimit(
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            50_000_000e6,
            25_000_000e6 / uint256(1 days)
        );
    }

    function test_BASE_SLL_AmendmentRateLimits() public onChain(ChainIdUtils.Base()) {
        ForeignController controller = ForeignController(Base.ALM_CONTROLLER);
        _assertRateLimit(
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            4_000_000e6,
            2_000_000e6 / uint256(1 days),
            3_582_233.729890e6,
            1736837373
        );
        _assertUnlimitedRateLimit(controller.LIMIT_USDC_TO_CCTP());

        executeAllPayloadsAndBridges();

        _assertUnlimitedRateLimit(controller.LIMIT_USDC_TO_CCTP());
        _assertRateLimit(
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            50_000_000e6,
            25_000_000e6 / uint256(1 days)
        );
    }

    function test_ETHEREUM_SLL_USDCRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        uint256 depositAmount        = 5_000_000e6;
        deal2(Ethereum.USDC, Ethereum.ALM_PROXY, 20 * depositAmount);

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

        // Slope is 10M/day, the deposit amount of 5M should be replenished in half a day.
        // Wait for half of that, and assert half of the rate limit was replenished.
        skip(1 days / 4);
        assertApproxEqAbs(rateLimits.getCurrentRateLimit(depositKey),  20_000_000e6 - depositAmount/2, 20000);
        // Wait for 1 more second to avoid rounding issues
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

        // Slope is 50M/day, the deposit amount of 5M should be replenished in a tenth of a day.
        // We wait for half of that, and assert half of the rate limit was replenished.
        skip(1 days / 20);
        assertApproxEqAbs(rateLimits.getCurrentRateLimit(depositKey),  50_000_000e18 - depositAmount/2, 5000);
        // Wait for 1 more second to avoid rounding issues
        skip(1 days / 20 + 1);
        assertEq(rateLimits.getCurrentRateLimit(depositKey),  50_000_000e18);
    }
}
