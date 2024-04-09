// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

contract SparkGnosis_20240417Test is SparkGnosisTestBase {

    address public constant POOL_IMPLEMENTATION_OLD = Gnosis.POOL_IMPL;
    address public constant POOL_IMPLEMENTATION_NEW = 0xCF86A65779e88bedfF0319FE13aE2B47358EB1bF;

    address public constant SXDAI            = 0xaf204776c7245bF4147c2612BF6e5972Ee483701;
    address public constant SXDAI_PRICE_FEED = 0x1D0f881Ce1a646E2f27Dec3c57Fa056cB838BCC2;
    address public constant USDC             = 0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83;
    address public constant USDC_PRICE_FEED  = 0x6FC2871B6d9A94866B7260896257Fd5b50c09900;
    address public constant USDT             = 0x4ECaBa5870353805a9F068101A40E0f32ed605C6;
    address public constant USDT_PRICE_FEED  = 0x6FC2871B6d9A94866B7260896257Fd5b50c09900;
    address public constant EURE             = 0xcB444e90D8198415266c6a2724b7900fb12FC56E;
    address public constant EURE_PRICE_FEED  = 0xab70BCB260073d036d1660201e9d5405F5829b7a;

    constructor() {
        id = '20240417';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl, 33352951);  // April 9, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function test_poolUpgrade() public {
        vm.prank(address(poolAddressesProvider));
        assertEq(IProxyLike(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_OLD);
        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), 0);  // This doesn't really need to be checked anymore as it was patched in code, but we have it for good measure

        GovHelpers.executePayload(vm, payload, executor);

        vm.prank(address(poolAddressesProvider));
        assertEq(IProxyLike(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_NEW);
        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), 0);
    }

    function test_collateralOnboarding() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        assertEq(allConfigsBefore.length, 4);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        assertEq(allConfigsAfter.length, 8);

        // sxDAI
        ReserveConfig memory sxdai = ReserveConfig({
            symbol:                  'sDAI',
            underlying:               SXDAI,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      70_00,
            liquidationThreshold:     75_00,
            liquidationBonus:         106_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            10_00,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         false,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'sDAI').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                40_000_000,
            borrowCap:                0,
            debtCeiling:              0,
            eModeCategory:            0
        });
        _validateReserveConfig(sxdai, allConfigsAfter);
        _validateInterestRateStrategy(
            sxdai.interestRateStrategy,
            sxdai.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.8e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0,
                variableRateSlope2:            0
            })
        );
        _validateAssetSourceOnOracle(poolAddressesProvider, SXDAI, SXDAI_PRICE_FEED);

        // USDC
        ReserveConfig memory usdc = ReserveConfig({
            symbol:                  'USDC',
            underlying:               USDC,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 6,
            ltv:                      0,
            liquidationThreshold:     0,
            liquidationBonus:         0,
            liquidationProtocolFee:   0,
            reserveFactor:            10_00,
            usageAsCollateralEnabled: false,
            borrowingEnabled:         true,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'USDC').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 true,
            isBorrowableInIsolation:  true,
            isFlashloanable:          true,
            supplyCap:                10_000_000,
            borrowCap:                8_000_000,
            debtCeiling:              0,
            eModeCategory:            0
        });
        _validateReserveConfig(usdc, allConfigsAfter);
        _validateInterestRateStrategy(
            usdc.interestRateStrategy,
            usdc.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.12e27,  // Equal to variableRateSlope1 as we don't use stable rates
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.12e27,
                variableRateSlope2:            0.5e27
            })
        );
        _validateAssetSourceOnOracle(poolAddressesProvider, USDC, USDC_PRICE_FEED);

        // USDT
        ReserveConfig memory usdt = ReserveConfig({
            symbol:                  'USDT',
            underlying:               USDT,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 6,
            ltv:                      0,
            liquidationThreshold:     0,
            liquidationBonus:         0,
            liquidationProtocolFee:   0,
            reserveFactor:            10_00,
            usageAsCollateralEnabled: false,
            borrowingEnabled:         true,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'USDT').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 true,
            isBorrowableInIsolation:  true,
            isFlashloanable:          true,
            supplyCap:                10_000_000,
            borrowCap:                8_000_000,
            debtCeiling:              0,
            eModeCategory:            0
        });
        _validateReserveConfig(usdt, allConfigsAfter);
        _validateInterestRateStrategy(
            usdt.interestRateStrategy,
            usdt.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.12e27,  // Equal to variableRateSlope1 as we don't use stable rates
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.12e27,
                variableRateSlope2:            0.5e27
            })
        );
        _validateAssetSourceOnOracle(poolAddressesProvider, USDT, USDT_PRICE_FEED);

        // EURe
        ReserveConfig memory eure = ReserveConfig({
            symbol:                  'EURe',
            underlying:               EURE,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      0,
            liquidationThreshold:     0,
            liquidationBonus:         0,
            liquidationProtocolFee:   0,
            reserveFactor:            10_00,
            usageAsCollateralEnabled: false,
            borrowingEnabled:         true,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'EURe').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 true,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                5_000_000,
            borrowCap:                4_000_000,
            debtCeiling:              0,
            eModeCategory:            0
        });
        _validateReserveConfig(eure, allConfigsAfter);
        _validateInterestRateStrategy(
            eure.interestRateStrategy,
            eure.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.07e27,  // Equal to variableRateSlope1 as we don't use stable rates
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.07e27,
                variableRateSlope2:            0.5e27
            })
        );
        _validateAssetSourceOnOracle(poolAddressesProvider, EURE, EURE_PRICE_FEED);
    }

}
