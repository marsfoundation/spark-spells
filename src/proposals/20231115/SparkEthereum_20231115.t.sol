// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';

import { SparkEthereum_20231115 } from './SparkEthereum_20231115.sol';
import { SparkGnosis_20231115 } from   './SparkGnosis_20231115.sol';

interface IL2BridgeExecutor {
    function execute(uint256 index) external;
}

interface D3MHubLike {
    function exec(bytes32) external;
}

contract SparkEthereum_20231115Test is SparkEthereumTestBase {

    address public constant GNOSIS_BRIDGE_EXECUTOR = 0xc4218C1127cB24a0D6c1e7D25dc34e10f2625f5A;
    address public constant D3M_JOB                = 0x1Bb799509b0B039345f910dfFb71eEfAc7022323;
    address public constant D3M_HUB                = 0x12F36cdEA3A28C35aC8C6Cc71D9265c17C74A27F;

    bytes32 public constant DAI_ILK = 0x4449524543542d535041524b2d44414900000000000000000000000000000000;

    Domain       mainnet;
    GnosisDomain gnosis;

    constructor() {
        id = '20231115';
    }

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        gnosis = new GnosisDomain(getChain('gnosis_chain'), mainnet);
        mainnet.selectFork();

        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*****************************************/
        /*** rETH Supply Cap Before Assertions ***/
        /*******************************************/

        ReserveConfig memory rETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'rETH');
        assertEq(rETHConfigBefore.supplyCap, 60_000);

        /*******************************************/
        /*** wstETH Supply Cap Before Assertions ***/
        /*******************************************/

        ReserveConfig memory wstETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');
        assertEq(wstETHConfigBefore.supplyCap, 400_000);

        /*********************************/
        /*** DAI LTV Before Assertions ***/
        /*********************************/

        ReserveConfig memory DAIConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        assertEq(DAIConfigBefore.ltv, 1);

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
        /*** rETH Supply Cap After Assertions ***/
        /******************************************/

        rETHConfigBefore.supplyCap = 80_000;
        _validateReserveConfig(rETHConfigBefore, allConfigsAfter);

        /******************************************/
        /*** wstETH Supply Cap After Assertions ***/
        /******************************************/

        wstETHConfigBefore.supplyCap = 800_000;
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

        /*****************************/
        /*** WBTC After Assertions ***/
        /*****************************/

        ReserveConfig memory wbtcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WBTC');

        ReserveConfig memory wbtcConfigExpected = ReserveConfig({
            symbol:                  'WBTC',
            underlying:               _findReserveConfigBySymbol(allConfigsBefore, 'WBTC').underlying,
            aToken:                   address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            variableDebtToken:        address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            stableDebtToken:          address(0),  // Mock, as they don't get validated in '_validateReserveConfig'
            decimals:                 8,
            ltv:                      70_00,
            liquidationThreshold:     75_00,
            liquidationBonus:         107_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            20_00,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         true,
            interestRateStrategy:     wbtcConfigAfter.interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                3_000,
            borrowCap:                2_000,
            debtCeiling:              0,
            eModeCategory:            0
        });
        _validateReserveConfig(wbtcConfigExpected, allConfigsAfter);
        _validateInterestRateStrategy(
            wbtcConfigAfter.interestRateStrategy,
            wbtcConfigExpected.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.60e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.02e27,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.02e27,
                variableRateSlope2:            3.00e27
            })
        );
        assertTrue(wbtcConfigAfter.aToken            != address(0));
        assertTrue(wbtcConfigAfter.variableDebtToken != address(0));
        assertTrue(wbtcConfigAfter.stableDebtToken   != address(0));
    }

    function testGnosisSpellExecution() public {
        GovHelpers.executePayload(vm, payload, executor);

        gnosis.relayFromHost(true);
        skip(2 days);

        IL2BridgeExecutor(GNOSIS_BRIDGE_EXECUTOR).execute(1);
    }

    function testD3MDeposit() public {
        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigs = createConfigurationSnapshot('', pool);

        address dai   = _findReserveConfigBySymbol(allConfigs, 'DAI').underlying;
        address spDai = _findReserveConfigBySymbol(allConfigs, 'DAI').aToken;

        uint256 daiSupplyBefore    = IERC20(dai).totalSupply();
        uint256 spDaiBalanceBefore = IERC20(dai).balanceOf(spDai);

        vm.prank(D3M_JOB);
        D3MHubLike(D3M_HUB).exec(DAI_ILK);

        uint256 daiSupplyAfter    = IERC20(dai).totalSupply();
        uint256 spDaiBalanceAfter = IERC20(dai).balanceOf(spDai);

        assertLt(daiSupplyBefore,    daiSupplyAfter);
        assertLt(spDaiBalanceBefore, spDaiBalanceAfter);

        assertEq(daiSupplyAfter - daiSupplyBefore, spDaiBalanceAfter - spDaiBalanceBefore);
    }

}
