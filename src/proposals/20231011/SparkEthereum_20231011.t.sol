// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20231011 } from './SparkEthereum_20231011.sol';

contract SparkEthereum_20231011Test is SparkEthereumTestBase {

    constructor() {
        id = '20231011';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /************************************/
        /*** USD eMode before validations ***/
        /************************************/

        DataTypes.EModeCategory memory emode = pool.getEModeCategoryData(2);
        assertEq(emode.ltv,                  0);
        assertEq(emode.liquidationThreshold, 0);
        assertEq(emode.liquidationBonus,     0);
        assertEq(emode.priceSource,          address(0));
        assertEq(emode.label,                '');

        /*******************************/
        /*** sDAI before validations ***/
        /*******************************/

        assertEq(_findReserveConfigBySymbol(allConfigsBefore, 'sDAI').eModeCategory, 0);

        /*******************************/
        /*** rETH before validations ***/
        /*******************************/

        assertEq(_findReserveConfigBySymbol(allConfigsBefore, 'rETH').supplyCap, 20_000);

        /**************************************/
        /*** USDC & USDT before validations ***/
        /**************************************/

        ReserveConfig memory usdcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDC');
        assertTrue(usdcConfigBefore.aToken            != address(0));
        assertTrue(usdcConfigBefore.variableDebtToken != address(0));
        assertTrue(usdcConfigBefore.stableDebtToken   != address(0));

        // There should be 8 markets before USDT
        assertEq(allConfigsBefore.length, 8);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /***********************************/
        /*** USD eMode after validations ***/
        /***********************************/

        emode = pool.getEModeCategoryData(2);
        assertEq(emode.ltv,                  91_00);
        assertEq(emode.liquidationThreshold, 92_00);
        assertEq(emode.liquidationBonus,     101_00);
        assertEq(emode.priceSource,          address(0));
        assertEq(emode.label,                'USD');

        /******************************/
        /*** sDAI after validations ***/
        /******************************/

        assertEq(_findReserveConfigBySymbol(allConfigsAfter, 'sDAI').eModeCategory, 2);

        /******************************/
        /*** rETH after validations ***/
        /******************************/

        assertEq(_findReserveConfigBySymbol(allConfigsAfter, 'rETH').supplyCap, 60_000);

        /*************************************/
        /*** USDC & USDT after validations ***/
        /*************************************/

        // There should be 9 markets after adding USDT
        assertEq(allConfigsAfter.length, 9);

        // USDT
        ReserveConfig memory usdtConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDT');
        ReserveConfig memory usdtConfigExpected = ReserveConfig({
            symbol:                  'USDT',
            underlying:               SparkEthereum_20231011(payload).USDT(),
            aToken:                   address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            variableDebtToken:        address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            stableDebtToken:          address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            decimals:                 6,
            ltv:                      0,
            liquidationThreshold:     0,
            liquidationBonus:         0,
            liquidationProtocolFee:   0,
            reserveFactor:            5_00,
            usageAsCollateralEnabled: false,
            borrowingEnabled:         true,
            interestRateStrategy:     usdtConfigAfter.interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 true,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                30_000_000,
            borrowCap:                0,
            debtCeiling:              0,
            eModeCategory:            2
        });
        _validateReserveConfig(usdtConfigExpected, allConfigsAfter);
        _validateInterestRateStrategy(
            usdtConfigAfter.interestRateStrategy,
            usdtConfigExpected.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          SparkEthereum_20231011(payload).VARIABLE_RATE(),
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            SparkEthereum_20231011(payload).VARIABLE_RATE(),
                variableRateSlope2:            0.2e27
            })
        );
        _validateAssetSourceOnOracle(
            poolAddressesProvider,
            SparkEthereum_20231011(payload).USDT(),
            SparkEthereum_20231011(payload).USDT_PRICE_FEED()
        );
        assertTrue(usdtConfigAfter.aToken            != address(0));
        assertTrue(usdtConfigAfter.variableDebtToken != address(0));
        assertTrue(usdtConfigAfter.stableDebtToken   != address(0));


        // USDC
        // Performing a full market validation
        // It should be the same as USDT market, with only difference in 'supplyCap' & 'priceFeed'
        ReserveConfig memory usdcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDC');
        ReserveConfig memory usdcConfigExpected = ReserveConfig({
            symbol:                  'USDC',
            underlying:               SparkEthereum_20231011(payload).USDC(),
            aToken:                   address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            variableDebtToken:        address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            stableDebtToken:          address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            decimals:                 6,
            ltv:                      0,
            liquidationThreshold:     0,
            liquidationBonus:         0,
            liquidationProtocolFee:   0,
            reserveFactor:            5_00,
            usageAsCollateralEnabled: false,
            borrowingEnabled:         true,
            interestRateStrategy:     usdcConfigAfter.interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 true,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                60_000_000,
            borrowCap:                0,
            debtCeiling:              0,
            eModeCategory:            2
        });
        _validateReserveConfig(usdcConfigExpected, allConfigsAfter);
        _validateInterestRateStrategy(
            usdcConfigAfter.interestRateStrategy,
            usdcConfigExpected.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          SparkEthereum_20231011(payload).VARIABLE_RATE(),
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            SparkEthereum_20231011(payload).VARIABLE_RATE(),
                variableRateSlope2:            0.2e27
            })
        );
        _validateAssetSourceOnOracle(
            poolAddressesProvider,
            SparkEthereum_20231011(payload).USDC(),
            SparkEthereum_20231011(payload).USDC_PRICE_FEED()
        );
        assertEq(usdcConfigBefore.aToken,            usdcConfigAfter.aToken);
        assertEq(usdcConfigBefore.variableDebtToken, usdcConfigAfter.variableDebtToken);
        assertEq(usdcConfigBefore.stableDebtToken,   usdcConfigAfter.stableDebtToken);
    }
}