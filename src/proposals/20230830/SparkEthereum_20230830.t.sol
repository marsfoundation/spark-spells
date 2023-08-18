// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { Ownable } from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/Ownable.sol';

import { SparkEthereum_20230830 } from './SparkEthereum_20230830.sol';

contract SparkEthereum_20230830Test is SparkEthereumTestBase {

    address public   constant WETH                           = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 public   constant OLD_WETH_OPTIMAL_USAGE_RATIO   = 0.80e27;
    uint256 public   constant NEW_WETH_OPTIMAL_USAGE_RATIO   = 0.90e27;
    uint256 public   constant OLD_WETH_VARIABLE_RATE_SLOPE_1 = 0.030e27;
    uint256 public   constant NEW_WETH_VARIABLE_RATE_SLOPE_1 = 0.028e27;
    uint256 public   constant OLD_WETH_VARIABLE_RATE_SLOPE_2 = 0.80e27;
    uint256 public   constant NEW_WETH_VARIABLE_RATE_SLOPE_2 = 1.20e27;

    address public   constant wstETH                         = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    uint256 public   constant OLD_WSTETH_SUPPLY_CAP          = 200_000;
    uint256 public   constant NEW_WSTETH_SUPPLY_CAP          = 400_000;

    constructor() {
        id = '20230830';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 17_935_850);
        // For now deploying the payload in the test
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
                
        /*******************************************/
        /*** wstETH Supply Cap Before Assertions ***/
        /*******************************************/
        
        ReserveConfig memory wstETHConfigBefore = _findReserveConfig(allConfigsBefore, wstETH);
        assertEq(wstETHConfigBefore.supplyCap, OLD_WSTETH_SUPPLY_CAP);

        /*****************************************************/
        /*** WETH Interest Rate Strategy Before Assertions ***/
        /*****************************************************/
        
        ReserveConfig memory WETHConfigBefore = _findReserveConfig(allConfigsBefore, WETH);
        IDefaultInterestRateStrategy interestRateStrategyBefore = IDefaultInterestRateStrategy(
            WETHConfigBefore.interestRateStrategy
        );

        _validateInterestRateStrategy(
            WETHConfigBefore.interestRateStrategy,
            WETHConfigBefore.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             OLD_WETH_OPTIMAL_USAGE_RATIO,
                optimalStableToTotalDebtRatio: interestRateStrategyBefore.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          OLD_WETH_VARIABLE_RATE_SLOPE_1,
                stableRateSlope1:              interestRateStrategyBefore.getStableRateSlope1(),
                stableRateSlope2:              interestRateStrategyBefore.getStableRateSlope2(),
                baseVariableBorrowRate:        interestRateStrategyBefore.getBaseVariableBorrowRate(),
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
                optimalStableToTotalDebtRatio: interestRateStrategyBefore.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          NEW_WETH_VARIABLE_RATE_SLOPE_1,
                stableRateSlope1:              interestRateStrategyBefore.getStableRateSlope1(),
                stableRateSlope2:              interestRateStrategyBefore.getStableRateSlope2(),
                baseVariableBorrowRate:        interestRateStrategyBefore.getBaseVariableBorrowRate(),
                variableRateSlope1:            NEW_WETH_VARIABLE_RATE_SLOPE_1,
                variableRateSlope2:            NEW_WETH_VARIABLE_RATE_SLOPE_2
            })
        );
    }
}