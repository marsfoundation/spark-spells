// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';

import { TestWithExecutor } from 'aave-helpers/GovHelpers.sol';

import {
    InitializableAdminUpgradeabilityProxy
} from 'aave-v3-core/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol';

import { IAaveOracle }                  from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import { IACLManager }                  from "aave-v3-core/contracts/interfaces/IACLManager.sol";
import { IDefaultInterestRateStrategy } from "aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol";
import { IERC20Detailed }               from "aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol";
import { IPoolAddressesProvider }       from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool }                        from "aave-v3-core/contracts/interfaces/IPool.sol";

import { ReserveConfiguration } from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

import { DefaultReserveInterestRateStrategy } from "aave-v3-core/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol";

import { DaiInterestRateStrategy }                              from '../../DaiInterestRateStrategy.sol';
import { SparkTestBase, InterestStrategyValues, ReserveConfig } from '../../SparkTestBase.sol';

import { PotAbstract } from 'dss-interfaces/Interfaces.sol';

import { SparkEthereum_20230525 } from './SparkEthereum_20230525.sol';

contract SparkEthereum_20230525Test is SparkTestBase, TestWithExecutor {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    uint256 internal constant WAD  = 1e18;
    uint256 internal constant RAY  = 1e27;
    uint256 internal constant RBPS = RAY / 10000;

    uint256 internal constant THREE_PT_FOUR_NINE = 1000000001087798189708544327;

    SparkEthereum_20230525 internal payload;

    address internal constant PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address internal constant EXECUTOR    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

    IAaveOracle            internal constant ORACLE                = IAaveOracle(0x8105f69D9C41644c6A0803fDA7D03Aa70996cFD9);
    IPool                  internal constant POOL                  = IPool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);
    IPoolAddressesProvider internal constant POOL_ADDRESS_PROVIDER = IPoolAddressesProvider(0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE);
    IACLManager            internal constant ACL_MANAGER           = IACLManager(0xdA135Cd78A086025BcdC87B038a1C462032b510C);

    address internal constant A_TOKEN_IMPL                   = 0x6175ddEc3B9b38c88157C10A01ed4A3fa8639cC6;
    address internal constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;
    address internal constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x113dc45c524404F91DcbbAbB103506bABC8Df0FE;
    address internal constant POOL_CONFIGURATOR              = 0x542DBa469bdE58FAeE189ffB60C6b49CE60E0738;
    address internal constant STABLE_DEBT_TOKEN_IMPL         = 0x026a5B6114431d8F3eF2fA0E1B2EDdDccA9c540E;
    address internal constant VARIABLE_DEBT_TOKEN_IMPL       = 0x86C71796CcDB31c3997F8Ec5C2E3dB3e9e40b985;
    address internal constant RETH_PRICE_FEED                = 0x05225Cd708bCa9253789C1374e4337a019e99D56;

    address internal constant DAI_INTEREST_RATE_STRATEGY = 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;
    address internal constant MCD_VAT                    = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address internal constant MCD_POT                    = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;

    address internal constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant USDC   = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant WBTC   = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant GNO    = 0x6810e776880C02933D47DB1b9fc05908e5386b96;
    address internal constant RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;

    bytes32 internal constant SPARK_ILK = 0x4449524543542d535041524b2d44414900000000000000000000000000000000;

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 17414900);

        // This needs to be done in Maker spell, but grant the subdao proxy admin access on the pool
        vm.prank(PAUSE_PROXY); ACL_MANAGER.addPoolAdmin(EXECUTOR);

        _selectPayloadExecutor(EXECUTOR);

        payload = SparkEthereum_20230525(0x41D7c79aE5Ecba7428283F66998DedFD84451e0e);
    }

    function testSpellExecution() public {
        createConfigurationSnapshot('pre-Spark-Ethereum-rETH-Listing', POOL);

        _executePayload(address(payload));

        ReserveConfig[] memory allConfigs = _getReservesConfigs(POOL);

        // rETH

        ReserveConfig memory reth = ReserveConfig({
            symbol:                  'rETH',
            underlying:               RETH,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      68_50,
            liquidationThreshold:     79_50,
            liquidationBonus:         107_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            15_00,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         true,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigs, 'rETH').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                20_000,
            borrowCap:                2_400,
            debtCeiling:              0,
            eModeCategory:            1
        });

        _validateReserveConfig(reth, allConfigs);

        _validateInterestRateStrategy(
            reth.interestRateStrategy,
            reth.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(POOL_ADDRESS_PROVIDER),
                optimalUsageRatio:             45 * (RAY / 100),
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          7 * (RAY / 100),      // Equal to variableRateSlope1 as we don't use stable rates
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            7 * (RAY / 100),
                variableRateSlope2:            300 * (RAY / 100)
            })
        );

        _validateAssetSourceOnOracle(POOL_ADDRESS_PROVIDER, RETH, payload.RETH_PRICE_FEED());

        // DAI Interest Rate Strategy

        _validateDaiInterestRateStrategy(
            _findReserveConfigBySymbol(allConfigs, 'DAI').interestRateStrategy,
            DAI_INTEREST_RATE_STRATEGY,
            DaiInterestStrategyValues({
                vat:                MCD_VAT,
                pot:                MCD_POT,
                ilk:                SPARK_ILK,
                baseRateConversion: RAY,
                borrowSpread:       0,
                supplySpread:       0,
                maxRate:            75 * (RAY / 100),
                performanceBonus:   0
            })
        );

        createConfigurationSnapshot('post-Spark-Ethereum-rETH-Listing', POOL);

        diffReports(
            'pre-Spark-Ethereum-rETH-Listing',
            'post-Spark-Ethereum-rETH-Listing'
        );
    }

    function testSpellExecution_manual_mainnet() public {

        /*********************/
        /*** Reserves List ***/
        /*********************/

        address[] memory reserves = POOL.getReservesList();

        assertEq(reserves.length, 7);

        assertEq(reserves[0], DAI);
        assertEq(reserves[1], SDAI);
        assertEq(reserves[2], USDC);
        assertEq(reserves[3], WETH);
        assertEq(reserves[4], WSTETH);
        assertEq(reserves[5], WBTC);
        assertEq(reserves[6], GNO);

        /**********************************************************/
        /*** RETH Onboarding - Reserve Configuration and Oracle ***/
        /**********************************************************/

        DataTypes.ReserveData memory data = POOL.getReserveData(RETH);

        assertEq(data.aTokenAddress,               address(0));
        assertEq(data.stableDebtTokenAddress,      address(0));
        assertEq(data.variableDebtTokenAddress,    address(0));
        assertEq(data.interestRateStrategyAddress, address(0));  // No assertions possible on strategy since it's not deployed

        assertEq(data.liquidityIndex,            0);
        assertEq(data.currentLiquidityRate,      0);
        assertEq(data.variableBorrowIndex,       0);
        assertEq(data.currentVariableBorrowRate, 0);
        assertEq(data.currentStableBorrowRate,   0);
        assertEq(data.lastUpdateTimestamp,       0);
        assertEq(data.id,                        0);
        assertEq(data.accruedToTreasury,         0);
        assertEq(data.unbacked,                  0);
        assertEq(data.isolationModeTotalDebt,    0);

        DataTypes.ReserveConfigurationMap memory cfg = data.configuration;

        assertEq(cfg.data, 0);  // Entire map is empty

        assertEq(ORACLE.getSourceOfAsset(RETH), address(0));

        /*****************************/
        /*** DAI Interest Strategy ***/
        /*****************************/

        data = POOL.getReserveData(DAI);

        assertEq(data.interestRateStrategyAddress, OLD_DAI_INTEREST_RATE_STRATEGY);

        DaiInterestRateStrategy daiStrategy = DaiInterestRateStrategy(data.interestRateStrategyAddress);

        assertEq(daiStrategy.vat(), MCD_VAT);
        assertEq(daiStrategy.pot(), MCD_POT);
        assertEq(daiStrategy.ilk(), SPARK_ILK);

        assertEq(daiStrategy.baseRateConversion(), RAY * 10 / 9);
        assertEq(daiStrategy.borrowSpread(),       0);
        assertEq(daiStrategy.supplySpread(),       0);
        assertEq(daiStrategy.maxRate(),            75_00 * RBPS);
        assertEq(daiStrategy.performanceBonus(),   0);

        daiStrategy.recompute();

        assertEq(daiStrategy.getBaseRate(), 0.011055923171930957297759999e27);  // ~1.11%

        ( uint256 supplyRate,, uint256 borrowRate ) = daiStrategy.calculateInterestRates(DataTypes.CalculateInterestRatesParams(
            0,
            0,
            0,
            0,
            1_000_000_000 * WAD,
            0,
            0,
            DAI,
            address(0)
        ));

        assertEq(supplyRate, 0.011055821081210007161332134e27);  // ~1.11%
        assertEq(borrowRate, 0.011055923171930957297759999e27);  // ~1.11% (slightly higher)

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        PotAbstract(MCD_POT).drip();
        vm.prank(PAUSE_PROXY); PotAbstract(MCD_POT).file("dsr", THREE_PT_FOUR_NINE);

        _executePayload(address(payload));

        /*********************/
        /*** Reserves List ***/
        /*********************/

        reserves = POOL.getReservesList();

        assertEq(reserves.length, 8);

        assertEq(reserves[0], DAI);
        assertEq(reserves[1], SDAI);
        assertEq(reserves[2], USDC);
        assertEq(reserves[3], WETH);
        assertEq(reserves[4], WSTETH);
        assertEq(reserves[5], WBTC);
        assertEq(reserves[6], GNO);
        assertEq(reserves[7], RETH);

        /**********************************************************/
        /*** RETH Onboarding - Reserve Configuration and Oracle ***/
        /**********************************************************/

        data = POOL.getReserveData(RETH);

        assertImplementation(POOL_CONFIGURATOR, data.aTokenAddress,            A_TOKEN_IMPL);
        assertImplementation(POOL_CONFIGURATOR, data.stableDebtTokenAddress,   STABLE_DEBT_TOKEN_IMPL);
        assertImplementation(POOL_CONFIGURATOR, data.variableDebtTokenAddress, VARIABLE_DEBT_TOKEN_IMPL);

        assertEq(IERC20Detailed(data.aTokenAddress).symbol(),            'sprETH');
        assertEq(IERC20Detailed(data.aTokenAddress).name(),              'Spark rETH');
        assertEq(IERC20Detailed(data.stableDebtTokenAddress).symbol(),   'stableDebtrETH');
        assertEq(IERC20Detailed(data.stableDebtTokenAddress).name(),     'Spark Stable Debt rETH');
        assertEq(IERC20Detailed(data.variableDebtTokenAddress).symbol(), 'variableDebtrETH');
        assertEq(IERC20Detailed(data.variableDebtTokenAddress).name(),   'Spark Variable Debt rETH');

        cfg = data.configuration;

        assertEq(cfg.getLtv(),                  68_50);
        assertEq(cfg.getLiquidationThreshold(), 79_50);
        assertEq(cfg.getLiquidationBonus(),     107_00);
        assertEq(cfg.getDecimals(),             18);

        assertEq(cfg.getActive(), true);
        assertEq(cfg.getFrozen(), false);
        assertEq(cfg.getPaused(), false);

        assertEq(cfg.getBorrowableInIsolation(),      false);
        assertEq(cfg.getSiloedBorrowing(),            false);
        assertEq(cfg.getBorrowingEnabled(),           true);
        assertEq(cfg.getStableRateBorrowingEnabled(), false);

        assertEq(cfg.getReserveFactor(),          15_00);
        assertEq(cfg.getBorrowCap(),              2_400);
        assertEq(cfg.getSupplyCap(),              20_000);
        assertEq(cfg.getDebtCeiling(),            0);
        assertEq(cfg.getLiquidationProtocolFee(), 10_00);
        assertEq(cfg.getUnbackedMintCap(),        0);
        assertEq(cfg.getEModeCategory(),          1);
        assertEq(cfg.getFlashLoanEnabled(),       true);

        assertEq(ORACLE.getSourceOfAsset(RETH), RETH_PRICE_FEED);

        assertApproxEqAbs(ORACLE.getAssetPrice(RETH), 2_000e8, 50e8);  // Within $50 of $2,000 (rETH oracle price)

        /*******************************************/
        /*** RETH Onboarding - Interest Strategy ***/
        /*******************************************/

        DefaultReserveInterestRateStrategy st = DefaultReserveInterestRateStrategy(data.interestRateStrategyAddress);

        assertEq(address(st.ADDRESSES_PROVIDER()), address(POOL_ADDRESS_PROVIDER));

        assertEq(st.OPTIMAL_USAGE_RATIO(),                   45 * RAY / 100);
        assertEq(st.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),    0);
        assertEq(st.MAX_EXCESS_USAGE_RATIO(),                55 * RAY / 100);
        assertEq(st.MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO(), RAY);

        assertEq(st.getVariableRateSlope1(),     7   * RAY / 100);
        assertEq(st.getVariableRateSlope2(),     300 * RAY / 100);
        assertEq(st.getStableRateSlope1(),       0);
        assertEq(st.getStableRateSlope2(),       0);
        assertEq(st.getStableRateExcessOffset(), 0);
        assertEq(st.getBaseStableBorrowRate(),   7 * RAY / 100);
        assertEq(st.getBaseVariableBorrowRate(), 0);
        assertEq(st.getMaxVariableBorrowRate(),  307 * RAY / 100);

        /*****************************/
        /*** DAI Interest Strategy ***/
        /*****************************/

        data = POOL.getReserveData(DAI);

        assertEq(data.interestRateStrategyAddress, NEW_DAI_INTEREST_RATE_STRATEGY);

        daiStrategy = DaiInterestRateStrategy(data.interestRateStrategyAddress);

        assertEq(daiStrategy.vat(), MCD_VAT);
        assertEq(daiStrategy.pot(), MCD_POT);
        assertEq(daiStrategy.ilk(), SPARK_ILK);

        assertEq(daiStrategy.baseRateConversion(), RAY);
        assertEq(daiStrategy.borrowSpread(),       0);
        assertEq(daiStrategy.supplySpread(),       0);
        assertEq(daiStrategy.maxRate(),            75_00 * RBPS);
        assertEq(daiStrategy.performanceBonus(),   0);

        daiStrategy.recompute();

        assertEq(daiStrategy.getBaseRate(), 0.034304803710648653896272000e27);  // 3.43%

        ( supplyRate,, borrowRate ) = daiStrategy.calculateInterestRates(DataTypes.CalculateInterestRatesParams(
            0,
            0,
            0,
            0,
            1_000_000_000 * WAD,
            0,
            0,
            DAI,
            address(0)
        ));

        assertEq(supplyRate, 0.034304486939078481944360326e27);  // 3.43% (slightly lower)
        assertEq(borrowRate, 0.034304803710648653896272000e27);  // 3.43%
    }

    function assertImplementation(address admin, address proxy, address implementation) internal {
        vm.prank(admin);
        assertEq(InitializableAdminUpgradeabilityProxy(payable(proxy)).implementation(), implementation);
    }

}
