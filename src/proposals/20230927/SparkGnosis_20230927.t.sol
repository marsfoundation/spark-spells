// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGnosis_20230927 } from './SparkGnosis_20230927.sol';

contract SparkGnosis_20230927Test is SparkGnosisTestBase {

    constructor() {
        id = '20230927';
    }

    function setUp() public {
        //vm.createSelectFork(getChain('gnosis_chain').rpcUrl);
        vm.createSelectFork("http://127.0.0.1:8545");
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        assertEq(allConfigsBefore.length, 0);
        DataTypes.EModeCategory memory emode = pool.getEModeCategoryData(1);
        assertEq(emode.ltv, 0);
        assertEq(emode.liquidationThreshold, 0);
        assertEq(emode.liquidationBonus, 0);
        assertEq(emode.priceSource, address(0));
        assertEq(emode.label, "");

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        assertEq(allConfigsAfter.length, 4);
        emode = pool.getEModeCategoryData(1);
        assertEq(emode.ltv, 85_00);
        assertEq(emode.liquidationThreshold, 90_00);
        assertEq(emode.liquidationBonus, 103_00);
        assertEq(emode.priceSource, address(0));
        assertEq(emode.label, "ETH");

        SparkGnosis_20230927 _payload = SparkGnosis_20230927(payload);

        // wxDAI
        ReserveConfig memory wxdai = ReserveConfig({
            symbol:                  'WXDAI',
            underlying:               _payload.WXDAI(),
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      70_00,
            liquidationThreshold:     75_00,
            liquidationBonus:         105_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            0,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         true,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'WXDAI').interestRateStrategy,
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
        _validateReserveConfig(wxdai, allConfigsAfter);
        _validateInterestRateStrategy(
            wxdai.interestRateStrategy,
            wxdai.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        48790164207174267760128000,
                variableRateSlope1:            0,
                variableRateSlope2:            0.5e27
            })
        );
        _validateAssetSourceOnOracle(poolAddressesProvider, _payload.WXDAI(), _payload.WXDAI_PRICE_FEED());

        // WETH
        ReserveConfig memory weth = ReserveConfig({
            symbol:                  'WETH',
            underlying:               _payload.WETH(),
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      70_00,
            liquidationThreshold:     75_00,
            liquidationBonus:         105_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            10_00,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         true,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'WETH').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                5_000,
            borrowCap:                3_000,
            debtCeiling:              0,
            eModeCategory:            1
        });
        _validateReserveConfig(weth, allConfigsAfter);
        _validateInterestRateStrategy(
            weth.interestRateStrategy,
            weth.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.028e27,      // Equal to variableRateSlope1 as we don't use stable rates
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0.01e27,
                variableRateSlope1:            0.028e27,
                variableRateSlope2:            1.2e27
            })
        );
        _validateAssetSourceOnOracle(poolAddressesProvider, _payload.WETH(), _payload.WETH_PRICE_FEED());

        // wstETH
        ReserveConfig memory wsteth = ReserveConfig({
            symbol:                  'wstETH',
            underlying:               _payload.WSTETH(),
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      65_00,
            liquidationThreshold:     72_50,
            liquidationBonus:         108_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            30_00,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         true,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'wstETH').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                5_000,
            borrowCap:                100,
            debtCeiling:              0,
            eModeCategory:            1
        });
        _validateReserveConfig(wsteth, allConfigsAfter);
        _validateInterestRateStrategy(
            wsteth.interestRateStrategy,
            wsteth.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.45e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.03e27,      // Equal to variableRateSlope1 as we don't use stable rates
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0.01e27,
                variableRateSlope1:            0.03e27,
                variableRateSlope2:            1e27
            })
        );
        _validateAssetSourceOnOracle(poolAddressesProvider, _payload.WSTETH(), _payload.WSTETH_PRICE_FEED());

        // GNO
        ReserveConfig memory gno = ReserveConfig({
            symbol:                  'GNO',
            underlying:               _payload.GNO(),
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      40_00,
            liquidationThreshold:     50_00,
            liquidationBonus:         112_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            0,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         false,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'GNO').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                200_000,
            borrowCap:                0,
            debtCeiling:              1_000_000_00,     // In units of cents - conversion happens in the config engine
            eModeCategory:            0
        });
        _validateReserveConfig(gno, allConfigsAfter);
        _validateInterestRateStrategy(
            gno.interestRateStrategy,
            gno.interestRateStrategy,
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
        _validateAssetSourceOnOracle(poolAddressesProvider, _payload.GNO(), _payload.GNO_PRICE_FEED());
    }

}
