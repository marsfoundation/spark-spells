// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

contract SparkGnosis_20240530Test is SparkGnosisTestBase {

    constructor() {
        id = '20240530';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl, 34058083);  // May 21, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testMarketConfigChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WXDAI');
        IDefaultInterestRateStrategy daiOldInterestRateStrategy = IDefaultInterestRateStrategy(
            daiConfigBefore.interestRateStrategy
        );
        _validateInterestRateStrategy(
            address(daiOldInterestRateStrategy),
            address(daiOldInterestRateStrategy),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: daiOldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.12e27,
                stableRateSlope1:              daiOldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              daiOldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.12e27,
                variableRateSlope2:            0.5e27
            })
        );

        ReserveConfig memory usdcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDC');
        assertEq(usdcConfigBefore.isSiloed, true);
        IDefaultInterestRateStrategy usdcOldInterestRateStrategy = IDefaultInterestRateStrategy(
            usdcConfigBefore.interestRateStrategy
        );
        _validateInterestRateStrategy(
            address(usdcOldInterestRateStrategy),
            address(usdcOldInterestRateStrategy),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: usdcOldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.12e27,
                stableRateSlope1:              usdcOldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              usdcOldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.12e27,
                variableRateSlope2:            0.5e27
            })
        );

        ReserveConfig memory usdtConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDT');
        assertEq(usdtConfigBefore.isSiloed,             true);
        assertEq(usdtConfigBefore.interestRateStrategy, usdcConfigBefore.interestRateStrategy);  // USDT and USDC have the same IRM params

        ReserveConfig memory eureConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'EURe');
        assertEq(eureConfigBefore.isSiloed, true);
        IDefaultInterestRateStrategy eureOldInterestRateStrategy = IDefaultInterestRateStrategy(
            eureConfigBefore.interestRateStrategy
        );
        _validateInterestRateStrategy(
            address(eureOldInterestRateStrategy),
            address(eureOldInterestRateStrategy),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: eureOldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.07e27,
                stableRateSlope1:              eureOldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              eureOldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.07e27,
                variableRateSlope2:            0.5e27
            })
        );

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');
        IDefaultInterestRateStrategy wethOldInterestRateStrategy = IDefaultInterestRateStrategy(
            wethConfigBefore.interestRateStrategy
        );
        _validateInterestRateStrategy(
            address(wethOldInterestRateStrategy),
            address(wethOldInterestRateStrategy),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: wethOldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.032e27,
                stableRateSlope1:              wethOldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              wethOldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        wethOldInterestRateStrategy.getBaseVariableBorrowRate(),
                variableRateSlope1:            0.032e27,
                variableRateSlope2:            wethOldInterestRateStrategy.getVariableRateSlope2()
            })
        );

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        InterestStrategyValues memory usdIRMValues = InterestStrategyValues({
            addressesProvider:             address(poolAddressesProvider),
            optimalUsageRatio:             0.95e27,
            optimalStableToTotalDebtRatio: 0,
            baseStableBorrowRate:          0.09e27,
            stableRateSlope1:              0,
            stableRateSlope2:              0,
            baseVariableBorrowRate:        0,
            variableRateSlope1:            0.09e27,
            variableRateSlope2:            0.15e27
        });

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WXDAI');
        daiConfigBefore.interestRateStrategy = daiConfigAfter.interestRateStrategy;
        _validateReserveConfig(daiConfigBefore, allConfigsAfter);
        _validateInterestRateStrategy(
            daiConfigAfter.interestRateStrategy,
            daiConfigAfter.interestRateStrategy,
            usdIRMValues
        );

        ReserveConfig memory usdcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDC');
        usdcConfigBefore.isSiloed = false;
        usdcConfigBefore.interestRateStrategy = usdcConfigAfter.interestRateStrategy;
        _validateReserveConfig(usdcConfigBefore, allConfigsAfter);
        _validateInterestRateStrategy(
            usdcConfigAfter.interestRateStrategy,
            usdcConfigAfter.interestRateStrategy,
            usdIRMValues
        );

        ReserveConfig memory usdtConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDT');
        usdtConfigBefore.isSiloed = false;
        usdtConfigBefore.interestRateStrategy = usdtConfigAfter.interestRateStrategy;
        _validateReserveConfig(usdtConfigBefore, allConfigsAfter);
        _validateInterestRateStrategy(
            usdtConfigAfter.interestRateStrategy,
            usdtConfigAfter.interestRateStrategy,
            usdIRMValues
        );

        ReserveConfig memory eureConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'EURe');
        eureConfigBefore.isSiloed = false;
        eureConfigBefore.interestRateStrategy = eureConfigAfter.interestRateStrategy;
        _validateReserveConfig(eureConfigBefore, allConfigsAfter);
        _validateInterestRateStrategy(
            eureConfigAfter.interestRateStrategy,
            eureConfigAfter.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: wethOldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.05e27,
                stableRateSlope1:              wethOldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              wethOldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        wethOldInterestRateStrategy.getBaseVariableBorrowRate(),
                variableRateSlope1:            0.05e27,
                variableRateSlope2:            0.15e27
            })
        );

        ReserveConfig memory wethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WETH');
        wethConfigBefore.interestRateStrategy = wethConfigAfter.interestRateStrategy;
        _validateReserveConfig(wethConfigBefore, allConfigsAfter);
        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            wethConfigAfter.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.8e27,
                optimalStableToTotalDebtRatio: wethOldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.025e27,
                stableRateSlope1:              wethOldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              wethOldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        wethOldInterestRateStrategy.getBaseVariableBorrowRate(),
                variableRateSlope1:            0.025e27,
                variableRateSlope2:            wethOldInterestRateStrategy.getVariableRateSlope2()
            })
        );
    }

    function testRemoveExecutorDelay() public {
        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getMinimumDelay(), 8 hours);
        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getDelay(),        2 days);

        executePayload(payload);

        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getMinimumDelay(), 0);
        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getDelay(),        0);
    }

}
