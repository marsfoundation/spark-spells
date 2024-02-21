// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { DataTypes }            from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import { IScaledBalanceToken }  from "aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol";
import { ReserveConfiguration } from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { WadRayMath }           from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";

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
        assertEq(eModeAfter.ltv,                  93_00);
        assertEq(eModeAfter.liquidationThreshold, 95_00);
        assertEq(eModeAfter.liquidationBonus,     eModeBefore.liquidationBonus);
        assertEq(eModeAfter.priceSource,          eModeBefore.priceSource);
        assertEq(eModeAfter.label,                eModeBefore.label);
    }

    function testCollateralUpdates() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory rETHConfigBefore   = _findReserveConfigBySymbol(allConfigsBefore, 'rETH');
        assertEq(rETHConfigBefore.ltv,                  68_50);
        assertEq(rETHConfigBefore.liquidationThreshold, 79_50);
        assertEq(rETHConfigBefore.liquidationBonus,     107_00);

        ReserveConfig memory sDAIConfigBefore   = _findReserveConfigBySymbol(allConfigsBefore, 'sDAI');
        assertEq(sDAIConfigBefore.ltv,                  74_00);
        assertEq(sDAIConfigBefore.liquidationThreshold, 76_00);
        assertEq(sDAIConfigBefore.liquidationBonus,     104_50);

        ReserveConfig memory WBTCConfigBefore   = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');
        assertEq(WBTCConfigBefore.ltv,                  70_00);
        assertEq(WBTCConfigBefore.liquidationThreshold, 75_00);
        assertEq(WBTCConfigBefore.liquidationBonus,     107_00);

        ReserveConfig memory WETHConfigBefore   = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');
        assertEq(WETHConfigBefore.ltv,                  80_00);
        assertEq(WETHConfigBefore.liquidationThreshold, 82_50);
        assertEq(WETHConfigBefore.liquidationBonus,     105_00);

        ReserveConfig memory wstETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');
        assertEq(wstETHConfigBefore.ltv,                  68_50);
        assertEq(wstETHConfigBefore.liquidationThreshold, 79_50);
        assertEq(wstETHConfigBefore.liquidationBonus,     107_00);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory rETHConfigAfter = rETHConfigBefore;
        rETHConfigAfter.ltv                  = 74_50;
        rETHConfigAfter.liquidationThreshold = 77_00;
        rETHConfigAfter.liquidationBonus     = 107_50;
        _validateReserveConfig(rETHConfigAfter, allConfigsAfter);

        ReserveConfig memory sDAIConfigAfter = sDAIConfigBefore;
        sDAIConfigAfter.ltv                  = 77_00;
        sDAIConfigAfter.liquidationThreshold = 80_00;
        sDAIConfigAfter.liquidationBonus     = 104_50;
        _validateReserveConfig(sDAIConfigAfter, allConfigsAfter);

        ReserveConfig memory WBTCConfigAfter = WBTCConfigBefore;
        WBTCConfigAfter.ltv                  = 73_00;
        WBTCConfigAfter.liquidationThreshold = 78_00;
        WBTCConfigAfter.liquidationBonus     = 105_00;
        _validateReserveConfig(WBTCConfigAfter, allConfigsAfter);

        ReserveConfig memory WETHConfigAfter = WETHConfigBefore;
        WETHConfigAfter.ltv                  = 80_50;
        WETHConfigAfter.liquidationThreshold = 83_00;
        WETHConfigAfter.liquidationBonus     = 105_00;
        _validateReserveConfig(WETHConfigAfter, allConfigsAfter);

        ReserveConfig memory wstETHConfigAfter = wstETHConfigBefore;
        wstETHConfigAfter.ltv                  = 78_50;
        wstETHConfigAfter.liquidationThreshold = 81_00;
        wstETHConfigAfter.liquidationBonus     = 106_00;
        _validateReserveConfig(wstETHConfigAfter, allConfigsAfter);
    }

    function testCapAutomatorDeploy() public {
        assertEq(address(capAutomator),                    0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef);
        assertEq(address(capAutomator.poolConfigurator()), address(poolConfigurator));
        assertEq(address(capAutomator.pool()),             address(pool));
        assertEq(IOwnable(address(capAutomator)).owner(),  executor);
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
