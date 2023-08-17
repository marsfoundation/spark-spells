// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { Ownable } from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/Ownable.sol';

import '../../SparkTestBase.sol';

import { SparkEthereum_20230830 } from './SparkEthereum_20230830.sol';


contract SparkEthereum_20230830Test is SparkEthereumTestBase {

    address internal constant PAUSE_PROXY             = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address public   constant WETH                    = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public   constant POOL_ADDRESSES_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    IPool   public   constant POOL                    = IPool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);

    uint256 public constant OLD_OPTIMAL_USAGE_RATIO = 0.80e27;
    uint256 public constant NEW_OPTIMAL_USAGE_RATIO = 0.90e27;
    
    uint256 public constant OLD_INTEREST_RATE = 0.030e27;
    uint256 public constant NEW_INTEREST_RATE = 0.038e27;

    constructor() {
        id = '20230830';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 17_892_780);
        // For now deploying the payload in the test
        payload = deployPayload();

        // Temporarily keeping the setup from the previous spell - will update after its execution
        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
        vm.prank(PAUSE_PROXY);
        Ownable(address(poolAddressesProvider)).transferOwnership(address(executor));
    }

    function testSpellSpecifics() public {
        
        /*****************************************************/
        /*** WETH Interest Rate Strategy Before Assertions ***/
        /*****************************************************/
        
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('pre-Spark-Goerli-20230830', POOL);
        ReserveConfig memory WETHConfigBefore = _findReserveConfig(allConfigsBefore, WETH);
        IDefaultInterestRateStrategy interestRateStrategyBefore = IDefaultInterestRateStrategy(
            WETHConfigBefore.interestRateStrategy
        );

        _validateInterestRateStrategy(
            WETHConfigBefore.interestRateStrategy,
            WETHConfigBefore.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             POOL_ADDRESSES_PROVIDER,
                optimalUsageRatio:             OLD_OPTIMAL_USAGE_RATIO,
                optimalStableToTotalDebtRatio: interestRateStrategyBefore.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          OLD_INTEREST_RATE,
                stableRateSlope1:              interestRateStrategyBefore.getStableRateSlope1(),
                stableRateSlope2:              interestRateStrategyBefore.getStableRateSlope2(),
                baseVariableBorrowRate:        interestRateStrategyBefore.getBaseVariableBorrowRate(),
                variableRateSlope1:            OLD_INTEREST_RATE,
                variableRateSlope2:            interestRateStrategyBefore.getVariableRateSlope2()
            })
        );
        
        /***********************/
        /*** Execute Payload ***/
        /***********************/
        
        GovHelpers.executePayload(vm, payload, executor);

        /*****************************************************/
        /*** WETH Interest Rate Strategy After Assertions ***/
        /*****************************************************/

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('post-Spark-Goerli-20230830', POOL);
        ReserveConfig memory WETHConfigAfter = _findReserveConfig(allConfigsAfter, WETH);

        _validateInterestRateStrategy(
            WETHConfigAfter.interestRateStrategy,
            WETHConfigAfter.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             POOL_ADDRESSES_PROVIDER,
                optimalUsageRatio:             NEW_OPTIMAL_USAGE_RATIO,
                optimalStableToTotalDebtRatio: interestRateStrategyBefore.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          NEW_INTEREST_RATE,
                stableRateSlope1:              interestRateStrategyBefore.getStableRateSlope1(),
                stableRateSlope2:              interestRateStrategyBefore.getStableRateSlope2(),
                baseVariableBorrowRate:        interestRateStrategyBefore.getBaseVariableBorrowRate(),
                variableRateSlope1:            NEW_INTEREST_RATE,
                variableRateSlope2:            interestRateStrategyBefore.getVariableRateSlope2()
            })
        );
    }
}