// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20231115 } from './SparkEthereum_20231115.sol';

contract SparkEthereum_20231115Test is SparkEthereumTestBase {

    uint256 public constant OLD_RETH_SUPPLY_CAP            = 60_000;
    uint256 public constant NEW_RETH_SUPPLY_CAP            = 80_000;
    uint256 public constant OLD_WSTETH_SUPPLY_CAP          = 400_000;
    uint256 public constant NEW_WSTETH_SUPPLY_CAP          = 800_000;
    uint256 public constant OLD_DAI_LTV                    = 1;
    uint256 public constant NEW_DAI_LTV                    = 0;
    uint256 public constant WETH_OPTIMAL_USAGE_RATIO       = 0.90e27;
    uint256 public constant OLD_WETH_BASE_RATE             = 0.01e27;
    uint256 public constant NEW_WETH_BASE_RATE             = 0;
    uint256 public constant OLD_WETH_VARIABLE_RATE_SLOPE_1 = 0.028e27;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_1 = 0.032e27;
    uint256 public constant OLD_WETH_VARIABLE_RATE_SLOPE_2 = 1.200e27;
    uint256 public constant NEW_WETH_VARIABLE_RATE_SLOPE_2 = 1.232e27;

    constructor() {
        id = '20231115';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18484640);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*****************************************/
        /*** rETH Supply Cap Before Assertions ***/
        /*******************************************/

        ReserveConfig memory rETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'rETH');
        assertEq(rETHConfigBefore.supplyCap, OLD_RETH_SUPPLY_CAP);

        /*******************************************/
        /*** wstETH Supply Cap Before Assertions ***/
        /*******************************************/

        ReserveConfig memory wstETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');
        assertEq(wstETHConfigBefore.supplyCap, OLD_WSTETH_SUPPLY_CAP);

        /*********************************/
        /*** DAI LTV Before Assertions ***/
        /*********************************/

        ReserveConfig memory DAIConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        assertEq(DAIConfigBefore.ltv, OLD_DAI_LTV);

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
                optimalUsageRatio:             WETH_OPTIMAL_USAGE_RATIO,
                optimalStableToTotalDebtRatio: interestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          OLD_WETH_VARIABLE_RATE_SLOPE_1,
                stableRateSlope1:              interestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              interestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        OLD_WETH_BASE_RATE,
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
        /*** rETH Supply Cap After Assertions ***/
        /******************************************/

        rETHConfigBefore.supplyCap = NEW_RETH_SUPPLY_CAP;
        _validateReserveConfig(rETHConfigBefore, allConfigsAfter);

        /******************************************/
        /*** wstETH Supply Cap After Assertions ***/
        /******************************************/

        wstETHConfigBefore.supplyCap = NEW_WSTETH_SUPPLY_CAP;
        _validateReserveConfig(wstETHConfigBefore, allConfigsAfter);

        /********************************/
        /*** DAI LTV After Assertions ***/
        /********************************/

        DAIConfigBefore.ltv = 0;
        _validateReserveConfig(DAIConfigBefore, allConfigsAfter);

        /****************************************************/
        /*** WETH Interest Rate Strategy After Assertions ***/
        /****************************************************/

        ReserveConfig memory wethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WETH');

        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            wethConfigAfter.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             WETH_OPTIMAL_USAGE_RATIO,
                optimalStableToTotalDebtRatio: interestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          NEW_WETH_VARIABLE_RATE_SLOPE_1,
                stableRateSlope1:              interestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              interestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        NEW_WETH_BASE_RATE,
                variableRateSlope1:            NEW_WETH_VARIABLE_RATE_SLOPE_1,
                variableRateSlope2:            NEW_WETH_VARIABLE_RATE_SLOPE_2
            })
        );
    }

}
