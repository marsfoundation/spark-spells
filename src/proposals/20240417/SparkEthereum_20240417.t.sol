// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

contract SparkEthereum_20240417Test is SparkEthereumTestBase {

    constructor() {
        id = '20240417';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19566509);  // April 2, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}
