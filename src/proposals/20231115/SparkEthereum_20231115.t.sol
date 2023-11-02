// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20231115 } from './SparkEthereum_20231115.sol';

contract SparkEthereum_20231115Test is SparkEthereumTestBase {

    uint256 public constant OLD_RETH_SUPPLY_CAP = 60_000;
    uint256 public constant NEW_RETH_SUPPLY_CAP = 80_000;

    uint256 public constant OLD_WSTETH_SUPPLY_CAP = 400_000;
    uint256 public constant NEW_WSTETH_SUPPLY_CAP = 600_000; // TBD

    uint256 public constant OLD_DAI_LTV = 1;
    uint256 public constant NEW_DAI_LTV = 0;

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
    }

}
