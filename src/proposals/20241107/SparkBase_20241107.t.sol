// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

contract SparkBase_20241107Test is SparkBaseTestBase {

    constructor() {
        id = '20241107';
    }

    function setUp() public {
        vm.createSelectFork(getChain('base').rpcUrl, 21451054);  // Oct 23, 2024
        payload = deployPayload();
    }
    
}
