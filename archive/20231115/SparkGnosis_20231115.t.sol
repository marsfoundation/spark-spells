// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGnosis_20231115 } from './SparkGnosis_20231115.sol';

contract SparkGnosis_20231115Test is SparkGnosisTestBase {

    constructor() {
        id = '20231115';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl, 30_855_038);
        payload = 0x41709f51E59ddbEbF37cE95257b2E4f2884a45F8;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*******************************************/
        /*** wstETH Supply Cap Before Assertions ***/
        /*******************************************/

        ReserveConfig memory wstETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');
        assertEq(wstETHConfigBefore.supplyCap, 5_000);

        /*****************************************************/
        /*** WETH Interest Rate Strategy Before Assertions ***/
        /*****************************************************/

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');
        IDefaultInterestRateStrategy oldInterestRateStrategy = IDefaultInterestRateStrategy(
            wethConfigBefore.interestRateStrategy
        );

        _validateInterestRateStrategy(
            address(oldInterestRateStrategy),
            address(oldInterestRateStrategy),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             oldInterestRateStrategy.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: oldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.028e27,
                stableRateSlope1:              oldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              oldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        0.01e27,
                variableRateSlope1:            0.028e27,
                variableRateSlope2:            oldInterestRateStrategy.getVariableRateSlope2()
            })
        );

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /******************************************/
        /*** wstETH Supply Cap After Assertions ***/
        /******************************************/

        wstETHConfigBefore.supplyCap = 10_000;
        _validateReserveConfig(wstETHConfigBefore, allConfigsAfter);

        /****************************************************/
        /*** WETH Interest Rate Strategy After Assertions ***/
        /****************************************************/

        ReserveConfig memory wethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WETH');

        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            wethConfigAfter.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             oldInterestRateStrategy.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: oldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.032e27,
                stableRateSlope1:              oldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              oldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.032e27,
                variableRateSlope2:            oldInterestRateStrategy.getVariableRateSlope2()
            })
        );
    }

}
