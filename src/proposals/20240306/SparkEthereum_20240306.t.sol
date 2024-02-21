// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

interface IOwnable {
    function owner() external view returns (address);
}

contract SparkEthereum_20240306Test is SparkEthereumTestBase {

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
        assertEq(sDAIConfigBefore.ltv,                  75_00);
        assertEq(sDAIConfigBefore.liquidationThreshold, 80_00);
        assertEq(sDAIConfigBefore.liquidationBonus,     105_00);

        ReserveConfig memory WBTCConfigBefore   = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');
        assertEq(WBTCConfigBefore.ltv,                  68_50);
        assertEq(WBTCConfigBefore.liquidationThreshold, 78_50);
        assertEq(WBTCConfigBefore.liquidationBonus,     107_00);

        ReserveConfig memory WETHConfigBefore   = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');
        assertEq(WETHConfigBefore.ltv,                  80_00);
        assertEq(WETHConfigBefore.liquidationThreshold, 85_00);
        assertEq(WETHConfigBefore.liquidationBonus,     105_00);

        ReserveConfig memory wstETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');
        assertEq(wstETHConfigBefore.ltv,                  68_50);
        assertEq(wstETHConfigBefore.liquidationThreshold, 79_50);
        assertEq(wstETHConfigBefore.liquidationBonus,     107_00);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory rETHConfig = rETHConfigBefore;
        rETHConfig.ltv                  = 74_50;
        rETHConfig.liquidationThreshold = 77_00;
        rETHConfig.liquidationBonus     = 107_50;
        _validateReserveConfig(rETHConfig, allConfigsAfter);

        ReserveConfig memory sDAIConfig = sDAIConfigBefore;
        sDAIConfig.ltv                  = 77_00;
        sDAIConfig.liquidationThreshold = 80_00;
        sDAIConfig.liquidationBonus     = 104_50;
        _validateReserveConfig(sDAIConfig, allConfigsAfter);

        ReserveConfig memory WBTCConfig = WBTCConfigBefore;
        WBTCConfig.ltv                  = 73_00;
        WBTCConfig.liquidationThreshold = 78_00;
        WBTCConfig.liquidationBonus     = 105_00;
        _validateReserveConfig(WBTCConfig, allConfigsAfter);

        ReserveConfig memory WETHConfig = WETHConfigBefore;
        WETHConfig.ltv                  = 80_50;
        WETHConfig.liquidationThreshold = 83_00;
        WETHConfig.liquidationBonus     = 105_00;
        _validateReserveConfig(WETHConfig, allConfigsAfter);

        ReserveConfig memory wstETHConfig = wstETHConfigBefore;
        wstETHConfig.ltv                  = 78_50;
        wstETHConfig.liquidationThreshold = 81_00;
        wstETHConfig.liquidationBonus     = 106_00;
        _validateReserveConfig(wstETHConfig, allConfigsAfter);
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

}
