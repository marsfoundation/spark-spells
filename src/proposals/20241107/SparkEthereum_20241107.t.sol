// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

contract SparkEthereum_20241107Test is SparkEthereumTestBase {

    constructor() {
        id = '20241107';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 21043334);  // Oct 25, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }
    
}
