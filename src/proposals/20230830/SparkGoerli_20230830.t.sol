// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGoerli_20230830 } from './SparkGoerli_20230830.sol';

contract SparkGoerli_20230830Test is SparkGoerliTestBase {

    uint256 public constant OLD_WETH_OPTIMAL_USAGE_RATIO   = 0.80e27;
    uint256 public constant NEW_WETH_OPTIMAL_USAGE_RATIO   = 0.90e27;
    uint256 public constant OLD_WETH_VARIABLE_RATE_SLOPE_1 = 0.030e27;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_1 = 0.028e27;
    uint256 public constant OLD_WETH_VARIABLE_RATE_SLOPE_2 = 0.80e27;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_2 = 1.20e27;
    uint256 public constant OLD_WSTETH_SUPPLY_CAP          = 200_000;
    uint256 public constant NEW_WSTETH_SUPPLY_CAP          = 400_000;

    constructor() {
        id = '20230830';
    }

    function setUp() public {
        vm.createSelectFork(getChain('goerli').rpcUrl, 9_562_130);
        payload = 0xFBdB6C5596Fc958B432Bf1c99268C72B1515DFf0;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*******************************************/
        /*** wstETH Supply Cap Before Assertions ***/
        /*******************************************/

        ReserveConfig memory wstETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');
        assertEq(wstETHConfigBefore.supplyCap, OLD_WSTETH_SUPPLY_CAP);

        /*****************************************************/
        /*** WETH Interest Rate Strategy Before Assertions ***/
        /*****************************************************/

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');
        IDefaultInterestRateStrategy interestRateStrategy = IDefaultInterestRateStrategy(
            wethConfigBefore.interestRateStrategy
        );

        _validateInterestRateStrategy(
            address(interestRateStrategy),
            address(interestRateStrategy),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             OLD_WETH_OPTIMAL_USAGE_RATIO,
                optimalStableToTotalDebtRatio: interestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          OLD_WETH_VARIABLE_RATE_SLOPE_1,
                stableRateSlope1:              interestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              interestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        interestRateStrategy.getBaseVariableBorrowRate(),
                variableRateSlope1:            OLD_WETH_VARIABLE_RATE_SLOPE_1,
                variableRateSlope2:            OLD_WETH_VARIABLE_RATE_SLOPE_2
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

        wstETHConfigBefore.supplyCap = NEW_WSTETH_SUPPLY_CAP;
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
                optimalUsageRatio:             NEW_WETH_OPTIMAL_USAGE_RATIO,
                optimalStableToTotalDebtRatio: interestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          NEW_WETH_VARIABLE_RATE_SLOPE_1,
                stableRateSlope1:              interestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              interestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        interestRateStrategy.getBaseVariableBorrowRate(),
                variableRateSlope1:            NEW_WETH_VARIABLE_RATE_SLOPE_1,
                variableRateSlope2:            NEW_WETH_VARIABLE_RATE_SLOPE_2
            })
        );
    }
}
