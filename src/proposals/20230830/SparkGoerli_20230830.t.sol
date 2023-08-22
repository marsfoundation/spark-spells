// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGoerli_20230830 } from './SparkGoerli_20230830.sol';

contract SparkGoerli_20230830Test is SparkGoerliTestBase {

    address public constant WETH   = 0x7D5afF7ab67b431cDFA6A94d50d3124cC4AB2611;
    address public constant WSTETH = 0x6E4F1e8d4c5E5E6e2781FD814EE0744cc16Eb352;

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
        vm.createSelectFork(getChain('goerli').rpcUrl, 9_534_370);
        // For now deploying the payload in the test
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        
        /*******************************************/
        /*** wstETH Supply Cap Before Assertions ***/
        /*******************************************/
        
        ReserveConfig memory wstETHConfigBefore = _findReserveConfig(allConfigsBefore, WSTETH);
        assertEq(wstETHConfigBefore.supplyCap, OLD_WSTETH_SUPPLY_CAP);

        /*****************************************************/
        /*** WETH Interest Rate Strategy Before Assertions ***/
        /*****************************************************/
        
        ReserveConfig memory wethConfigBefore = _findReserveConfig(allConfigsBefore, WETH);
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

        ReserveConfig memory WETHConfigAfter = _findReserveConfig(allConfigsAfter, WETH);

        _validateInterestRateStrategy(
            WETHConfigAfter.interestRateStrategy,
            WETHConfigAfter.interestRateStrategy,
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