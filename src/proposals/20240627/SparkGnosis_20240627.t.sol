// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

contract SparkGnosis_20240627Test is SparkGnosisTestBase {

    address public constant USDCE            = 0x2a22f9c3b484c3629090FeED35F17Ff8F88f76F0;
    address public constant USDCE_PRICE_FEED = 0x6FC2871B6d9A94866B7260896257Fd5b50c09900;

    constructor() {
        id = '20240627';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl, 34526700);  // June 18, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testNewListing() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        assertEq(allConfigsBefore.length, 8);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        assertEq(allConfigsAfter.length, 9);

        ReserveConfig memory usdce = ReserveConfig({
            symbol:                  'USDC.e',
            underlying:               USDCE,
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
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'USDC.e').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  true,
            isFlashloanable:          true,
            supplyCap:                10_000_000,
            borrowCap:                8_000_000,
            debtCeiling:              0,
            eModeCategory:            0
        });

        _validateReserveConfig(usdce, allConfigsAfter);

        _validateInterestRateStrategy(
            usdce.interestRateStrategy,
            usdce.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.09e27,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.09e27,
                variableRateSlope2:            0.15e27
            })
        );

        _validateAssetSourceOnOracle(poolAddressesProvider, USDCE, USDCE_PRICE_FEED);
    }

    function testExistingMarketUpdates() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory usdcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDC');

        assertEq(usdcConfigBefore.borrowCap, 8_000_000);

        IDefaultInterestRateStrategy oldInterestRateStrategy = IDefaultInterestRateStrategy(
            usdcConfigBefore.interestRateStrategy
        );

        InterestStrategyValues memory oldInterestStrategyValues = InterestStrategyValues({
            addressesProvider:             address(poolAddressesProvider),
            optimalUsageRatio:             0.95e27,
            optimalStableToTotalDebtRatio: oldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
            baseStableBorrowRate:          oldInterestRateStrategy.getBaseStableBorrowRate(),
            stableRateSlope1:              oldInterestRateStrategy.getStableRateSlope1(),
            stableRateSlope2:              oldInterestRateStrategy.getStableRateSlope2(),
            baseVariableBorrowRate:        oldInterestRateStrategy.getBaseVariableBorrowRate(),
            variableRateSlope1:            oldInterestRateStrategy.getVariableRateSlope1(),
            variableRateSlope2:            0.15e27
        });
        _validateInterestRateStrategy(
            address(oldInterestRateStrategy),
            address(oldInterestRateStrategy),
            oldInterestStrategyValues
        );

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory usdcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDC');

        usdcConfigBefore.borrowCap = 1_000_000;
        usdcConfigBefore.interestRateStrategy = usdcConfigAfter.interestRateStrategy;

        _validateReserveConfig(usdcConfigBefore, allConfigsAfter);

        IDefaultInterestRateStrategy newInterestRateStrategy = IDefaultInterestRateStrategy(
            usdcConfigAfter.interestRateStrategy
        );

        InterestStrategyValues memory newInterestStrategyValues = InterestStrategyValues({
            addressesProvider:             address(poolAddressesProvider),
            optimalUsageRatio:             0.80e27,
            optimalStableToTotalDebtRatio: oldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
            baseStableBorrowRate:          oldInterestRateStrategy.getBaseStableBorrowRate(),
            stableRateSlope1:              oldInterestRateStrategy.getStableRateSlope1(),
            stableRateSlope2:              oldInterestRateStrategy.getStableRateSlope2(),
            baseVariableBorrowRate:        oldInterestRateStrategy.getBaseVariableBorrowRate(),
            variableRateSlope1:            oldInterestRateStrategy.getVariableRateSlope1(),
            variableRateSlope2:            0.50e27
        });
        _validateInterestRateStrategy(
            address(newInterestRateStrategy),
            address(newInterestRateStrategy),
            newInterestStrategyValues
        );
    }

}
