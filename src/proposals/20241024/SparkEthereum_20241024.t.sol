// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20241024 } from './SparkEthereum_20241024.sol';

contract SparkEthereum_20241024Test is SparkEthereumTestBase {

    constructor() {
        id = '20241024';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*****************************************/
        /*** WBTC Supply Cap Before Assertions ***/
        /*******************************************/

        ReserveConfig memory WBTCConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');
        assertEq(WBTCConfigBefore.supplyCap, 3_000);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /******************************************/
        /*** WBTC Supply Cap After Assertions ***/
        /******************************************/

        WBTCConfigBefore.supplyCap = 5_000;
        _validateReserveConfig(WBTCConfigBefore, allConfigsAfter);
    }

}
