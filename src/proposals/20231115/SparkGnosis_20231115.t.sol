// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGnosis_20231115 } from './SparkGnosis_20231115.sol';

contract SparkGnosis_20231115Test is SparkGnosisTestBase {

    address public constant WSTETH = 0x6C76971f98945AE98dD7d4DFcA8711ebea946eA6;

    uint256 public constant OLD_WSTETH_SUPPLY_CAP = 5_000;
    uint256 public constant NEW_WSTETH_SUPPLY_CAP = 10_000;

    constructor() {
        id = '20231115';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl, 30758975);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*******************************************/
        /*** wstETH Supply Cap Before Assertions ***/
        /*******************************************/

        ReserveConfig memory wstETHConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');
        assertEq(wstETHConfigBefore.supplyCap, OLD_WSTETH_SUPPLY_CAP);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /******************************************/
        /*** wstETH Supply Cap After Assertions ***/
        /******************************************/

        wstETHConfigBefore.supplyCap = NEW_WSTETH_SUPPLY_CAP;
        _validateReserveConfig(wstETHConfigBefore, allConfigsAfter);

    }

}
