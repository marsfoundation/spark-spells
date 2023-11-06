// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';

import { SparkEthereum_20231115 } from './SparkEthereum_20231115.sol';
import { SparkGnosis_20231115 } from   './SparkGnosis_20231115.sol';

interface IL2BridgeExecutor {
    function execute(uint256 index) external;
}

contract SparkEthereum_20231115Test is SparkEthereumTestBase {

    address public constant WBTC            = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WBTC_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    address public constant GNOSIS_BRIDGE_EXECUTOR = 0xc4218C1127cB24a0D6c1e7D25dc34e10f2625f5A;

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

    uint256 public constant NEW_WBTC_SUPPLY_CAP            = 3_000;
    uint256 public constant NEW_WBTC_BORROW_CAP            = 2_000;
    uint256 public constant NEW_WBTC_LTV                   = 70_00;
    uint256 public constant NEW_WBTC_LIQ_THRESHOLD         = 75_00;
    uint256 public constant NEW_WBTC_LIQ_BONUS             = 7_00;
    uint256 public constant NEW_WBTC_OPTIMAL_USAGE_RATIO   = 60_00;
    uint256 public constant NEW_WBTC_BASE_RATE             = 0;
    uint256 public constant NEW_WBTC_VARIABLE_RATE_SLOPE_1 = 2_00;
    uint256 public constant NEW_WBTC_VARIABLE_RATE_SLOPE_2 = 302_00;
    uint256 public constant NEW_WBTC_RESERVE_FACTOR        = 20_00;

    Domain       mainnet;
    GnosisDomain gnosis;

    constructor() {
        id = '20231115';
    }

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        gnosis = new GnosisDomain(getChain('gnosis_chain'), mainnet);

        gnosis.selectFork();
        new SparkGnosis_20231115();

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

        /*****************************/
        /*** WBTC After Assertions ***/
        /*****************************/

        ReserveConfig memory wbtcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WBTC');

        ReserveConfig memory wbtcConfigExpected = ReserveConfig({
            symbol:                  'WBTC',
            underlying:               WBTC,
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
            isSiloed:                 true,
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
                variableRateSlope2:            3.02e27
            })
        );
        assertTrue(wbtcConfigAfter.aToken            != address(0));
        assertTrue(wbtcConfigAfter.variableDebtToken != address(0));
        assertTrue(wbtcConfigAfter.stableDebtToken   != address(0));

        /******************************/
        /*** Gnosis Spell Execution ***/
        /******************************/

        gnosis.relayFromHost(true);
        skip(2 days);

        IL2BridgeExecutor(GNOSIS_BRIDGE_EXECUTOR).execute(1);
    }

}
