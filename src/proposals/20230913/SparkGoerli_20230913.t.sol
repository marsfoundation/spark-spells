// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGoerli_20230913 } from './SparkGoerli_20230913.sol';

contract SparkGoerli_20230913Test is SparkGoerliTestBase {

    uint128 public constant OLD_FLASHLOAN_PREMIUM_TOTAL = 9;
    uint128 public constant NEW_FLASHLOAN_PREMIUM_TOTAL = 0;

    constructor() {
        id = '20230913';
    }

    function setUp() public {
        vm.createSelectFork(getChain('goerli').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        /*************************************************/
        /*** FLASHLOAN_PREMIUM_TOTAL Before Assertions ***/
        /*************************************************/

        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), OLD_FLASHLOAN_PREMIUM_TOTAL);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        /************************************************/
        /*** FLASHLOAN_PREMIUM_TOTAL After Assertions ***/
        /************************************************/

        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), NEW_FLASHLOAN_PREMIUM_TOTAL);
    }
}
