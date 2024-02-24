// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { DataTypes }                    from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import { IDefaultInterestRateStrategy } from "aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol";
import { IScaledBalanceToken }          from "aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol";
import { ReserveConfiguration }         from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { WadRayMath }                   from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";

import { IERC20 } from '../../interfaces/IERC20.sol';

import '../../SparkTestBase.sol';

interface IOwnable {
    function owner() external view returns (address);
}

interface IERC20WithDecimals is IERC20 {
    function decimals() external view returns (uint256);
}

contract SparkEthereum_20240306Test is SparkEthereumTestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using WadRayMath for uint256;

    constructor() {
        id = '20240306';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19270337);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testEModeUpdate() public {
        DataTypes.EModeCategory memory eModeBefore = pool.getEModeCategoryData(1);

        assertEq(eModeBefore.ltv,                  90_00);
        assertEq(eModeBefore.liquidationThreshold, 93_00);
        assertEq(eModeBefore.liquidationBonus,     101_00);
        assertEq(eModeBefore.priceSource,          address(0));
        assertEq(eModeBefore.label,                'ETH');

        GovHelpers.executePayload(vm, payload, executor);

        DataTypes.EModeCategory memory eModeAfter = pool.getEModeCategoryData(1);

        assertEq(eModeAfter.ltv,                  92_00);
        assertEq(eModeAfter.liquidationThreshold, eModeBefore.liquidationThreshold);
        assertEq(eModeAfter.liquidationBonus,     eModeBefore.liquidationBonus);
        assertEq(eModeAfter.priceSource,          eModeBefore.priceSource);
        assertEq(eModeAfter.label,                eModeBefore.label);
    }

    function testMarketUpdates() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*******************/
        /*** rETH Before ***/
        /*******************/

        ReserveConfig memory rethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'rETH');

        assertEq(rethConfigBefore.ltv,                  68_50);
        assertEq(rethConfigBefore.liquidationThreshold, 79_50);
        assertEq(rethConfigBefore.liquidationBonus,     107_00);

        IDefaultInterestRateStrategy rethIRSBefore = IDefaultInterestRateStrategy(
            rethConfigBefore.interestRateStrategy
        );

        _validateInterestRateStrategy(
            address(rethIRSBefore),
            address(rethIRSBefore),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             rethIRSBefore.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: rethIRSBefore.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.070e27,
                stableRateSlope1:              rethIRSBefore.getStableRateSlope1(),
                stableRateSlope2:              rethIRSBefore.getStableRateSlope2(),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.070e27,
                variableRateSlope2:            3.000e27
            })
        );

        /*******************/
        /*** sDAI Before ***/
        /*******************/

        ReserveConfig memory sdaiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'sDAI');

        assertEq(sdaiConfigBefore.ltv,                  74_00);
        assertEq(sdaiConfigBefore.liquidationThreshold, 76_00);
        assertEq(sdaiConfigBefore.liquidationBonus,     104_50);

        /*******************/
        /*** WBTC Before ***/
        /*******************/

        ReserveConfig memory wbtcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfigBefore.ltv,                  70_00);
        assertEq(wbtcConfigBefore.liquidationThreshold, 75_00);
        assertEq(wbtcConfigBefore.liquidationBonus,     107_00);

        /*******************/
        /*** WETH Before ***/
        /*******************/

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');

        assertEq(wethConfigBefore.ltv,                  80_00);
        assertEq(wethConfigBefore.liquidationThreshold, 82_50);
        assertEq(wethConfigBefore.liquidationBonus,     105_00);

        IDefaultInterestRateStrategy wethIRSBefore = IDefaultInterestRateStrategy(
            wethConfigBefore.interestRateStrategy
        );

        _validateInterestRateStrategy(
            address(wethIRSBefore),
            address(wethIRSBefore),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             wethIRSBefore.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: wethIRSBefore.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.032e27,
                stableRateSlope1:              wethIRSBefore.getStableRateSlope1(),
                stableRateSlope2:              wethIRSBefore.getStableRateSlope2(),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.032e27,
                variableRateSlope2:            1.200e27
            })
        );

        /*********************/
        /*** wstETH Before ***/
        /*********************/

        ReserveConfig memory wstethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');

        assertEq(wstethConfigBefore.ltv,                  68_50);
        assertEq(wstethConfigBefore.liquidationThreshold, 79_50);
        assertEq(wstethConfigBefore.liquidationBonus,     107_00);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /*******************/
        /*** rETH After ****/
        /*******************/

        ReserveConfig memory rethConfigAfter = rethConfigBefore;

        rethConfigAfter.interestRateStrategy = _findReserveConfigBySymbol(allConfigsAfter, 'rETH').interestRateStrategy;

        rethConfigAfter.ltv                  = 79_00;
        rethConfigAfter.liquidationThreshold = 80_00;

        _validateReserveConfig(rethConfigAfter, allConfigsAfter);

        _validateInterestRateStrategy(
            rethConfigAfter.interestRateStrategy,
            rethConfigAfter.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             rethIRSBefore.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: rethIRSBefore.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          rethIRSBefore.getBaseStableBorrowRate(),
                stableRateSlope1:              rethIRSBefore.getStableRateSlope1(),
                stableRateSlope2:              rethIRSBefore.getStableRateSlope2(),
                baseVariableBorrowRate:        0.0025e27,
                variableRateSlope1:            rethIRSBefore.getVariableRateSlope1(),
                variableRateSlope2:            rethIRSBefore.getVariableRateSlope2()
            })
        );

        /*******************/
        /*** sDAI After ****/
        /*******************/

        ReserveConfig memory sdaiConfigAfter = sdaiConfigBefore;

        sdaiConfigAfter.ltv                  = 79_00;
        sdaiConfigAfter.liquidationThreshold = 80_00;
        sdaiConfigAfter.liquidationBonus     = 105_00;

        _validateReserveConfig(sdaiConfigAfter, allConfigsAfter);

        /*******************/
        /*** WBTC After ****/
        /*******************/

        ReserveConfig memory wbtcConfigAfter = wbtcConfigBefore;

        wbtcConfigAfter.ltv = 74_00;

        _validateReserveConfig(wbtcConfigAfter, allConfigsAfter);

        /*******************/
        /*** WETH After ****/
        /*******************/

        ReserveConfig memory wethConfigAfter = wethConfigBefore;

        wethConfigAfter.interestRateStrategy = _findReserveConfigBySymbol(allConfigsAfter, 'WETH').interestRateStrategy;

        wethConfigAfter.ltv                  = 82_00;
        wethConfigAfter.liquidationThreshold = 83_00;

        _validateReserveConfig(wethConfigAfter, allConfigsAfter);

        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            wethConfigAfter.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             wethIRSBefore.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: wethIRSBefore.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.028e27,
                stableRateSlope1:              wethIRSBefore.getStableRateSlope1(),
                stableRateSlope2:              wethIRSBefore.getStableRateSlope2(),
                baseVariableBorrowRate:        wethIRSBefore.getBaseVariableBorrowRate(),
                variableRateSlope1:            0.028e27,
                variableRateSlope2:            wethIRSBefore.getVariableRateSlope2()
            })
        );

        /*********************/
        /*** wstETH After ****/
        /*********************/

        ReserveConfig memory wstethConfigAfter = wstethConfigBefore;

        wstethConfigAfter.ltv                  = 79_00;
        wstethConfigAfter.liquidationThreshold = 80_00;

        _validateReserveConfig(wstethConfigAfter, allConfigsAfter);
    }

    function testCapAutomatorDeploy() public {
        assertEq(address(capAutomator), 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef);

        assertEq(address(capAutomator.poolConfigurator()), address(poolConfigurator));
        assertEq(address(capAutomator.pool()),             address(pool));

        assertEq(IOwnable(address(capAutomator)).owner(), executor);
    }

    function testCapAutomatorConfiguration() public {
        assertEq(aclManager.isRiskAdmin(address(capAutomator)), false);

        _assertSupplyCapConfigNotSet(RETH);
        _assertBorrowCapConfigNotSet(RETH);

        _assertSupplyCapConfigNotSet(SDAI);
        _assertBorrowCapConfigNotSet(SDAI);

        _assertSupplyCapConfigNotSet(USDC);
        _assertBorrowCapConfigNotSet(USDC);

        _assertSupplyCapConfigNotSet(USDT);
        _assertBorrowCapConfigNotSet(USDT);

        _assertSupplyCapConfigNotSet(WBTC);
        _assertBorrowCapConfigNotSet(WBTC);

        _assertSupplyCapConfigNotSet(WETH);
        _assertBorrowCapConfigNotSet(WETH);

        _assertSupplyCapConfigNotSet(WSTETH);
        _assertBorrowCapConfigNotSet(WSTETH);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(aclManager.isRiskAdmin(address(capAutomator)), true);

        /************/
        /*** rETH ***/
        /************/

        _assertSupplyCapConfig({
            asset:            RETH,
            max:              80_000,
            gap:              10_000,
            increaseCooldown: 12 hours
        });

        _assertBorrowCapConfig({
            asset:            RETH,
            max:              2_400,
            gap:              100,
            increaseCooldown: 12 hours
        });

        /************/
        /*** sDAI ***/
        /************/

        _assertSupplyCapConfig({
            asset:            SDAI,
            max:              1_000_000_000,
            gap:              50_000_000,
            increaseCooldown: 12 hours
        });

        _assertBorrowCapConfigNotSet(SDAI);

        /************/
        /*** USDC ***/
        /************/

        _assertSupplyCapConfigNotSet(USDC);

        _assertBorrowCapConfig({
            asset:            USDC,
            max:              57_000_000,
            gap:              6_000_000,
            increaseCooldown: 12 hours
        });

        /************/
        /*** USDT ***/
        /************/

        _assertSupplyCapConfigNotSet(USDT);

        _assertBorrowCapConfig({
            asset:            USDT,
            max:              28_500_000,
            gap:              3_000_000,
            increaseCooldown: 12 hours
        });

        /************/
        /*** WBTC ***/
        /************/

        _assertSupplyCapConfig({
            asset:            WBTC,
            max:              5_000,
            gap:              500,
            increaseCooldown: 12 hours
        });

        _assertBorrowCapConfig({
            asset:            WBTC,
            max:              2_000,
            gap:              100,
            increaseCooldown: 12 hours
        });

        /************/
        /*** WETH ***/
        /************/

        _assertSupplyCapConfig({
            asset:            WETH,
            max:              2_000_000,
            gap:              150_000,
            increaseCooldown: 12 hours
        });

        _assertBorrowCapConfig({
            asset:            WETH,
            max:              1_000_000,
            gap:              10_000,
            increaseCooldown: 12 hours
        });

        /**************/
        /*** wstETH ***/
        /**************/

        _assertSupplyCapConfig({
            asset:            WSTETH,
            max:              1_200_000,
            gap:              50_000,
            increaseCooldown: 12 hours
        });

        _assertBorrowCapConfig({
            asset:            WSTETH,
            max:              3_000,
            gap:              100,
            increaseCooldown: 12 hours
        });
    }

    function testCapAutomatorCapUpdates() public {
        GovHelpers.executePayload(vm, payload, executor);

        _assertAutomatedCapsUpdate(RETH);
        _assertAutomatedCapsUpdate(SDAI);
        _assertAutomatedCapsUpdate(USDC);
        _assertAutomatedCapsUpdate(USDT);
        _assertAutomatedCapsUpdate(WBTC);
        _assertAutomatedCapsUpdate(WETH);
        _assertAutomatedCapsUpdate(WSTETH);
    }

    function _assertAutomatedCapsUpdate(address asset) internal {
        DataTypes.ReserveData memory reserveDataBefore = pool.getReserveData(asset);

        uint256 supplyCapBefore = reserveDataBefore.configuration.getSupplyCap();
        uint256 borrowCapBefore = reserveDataBefore.configuration.getBorrowCap();

        capAutomator.exec(asset);

        DataTypes.ReserveData memory reserveDataAfter = pool.getReserveData(asset);

        uint256 supplyCapAfter = reserveDataAfter.configuration.getSupplyCap();
        uint256 borrowCapAfter = reserveDataAfter.configuration.getBorrowCap();

        uint48 max;
        uint48 gap;

        (max, gap,,,) = capAutomator.supplyCapConfigs(asset);

        if (max > 0) {
            uint256 currentSupply = (IScaledBalanceToken(reserveDataAfter.aTokenAddress).scaledTotalSupply() + uint256(reserveDataAfter.accruedToTreasury))
                .rayMul(reserveDataAfter.liquidityIndex)
                / 10 ** IERC20WithDecimals(reserveDataAfter.aTokenAddress).decimals();

            uint256 expectedSupplyCap = uint256(max) < currentSupply + uint256(gap)
                ? uint256(max)
                : currentSupply + uint256(gap);

            assertEq(supplyCapAfter, expectedSupplyCap);
        } else {
            assertEq(supplyCapAfter, supplyCapBefore);
        }

        (max, gap,,,) = capAutomator.borrowCapConfigs(asset);

        if (max > 0) {
            uint256 currentBorrows = IERC20(reserveDataAfter.variableDebtTokenAddress).totalSupply() / 10 ** IERC20WithDecimals(reserveDataAfter.variableDebtTokenAddress).decimals();

            uint256 expectedBorrowCap = uint256(max) < currentBorrows + uint256(gap)
                ? uint256(max)
                : currentBorrows + uint256(gap);

            assertEq(borrowCapAfter, expectedBorrowCap);
        } else {
            assertEq(borrowCapAfter, borrowCapBefore);
        }
    }

}
