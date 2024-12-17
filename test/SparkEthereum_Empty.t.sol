// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../src/SparkTestBase.sol';

// Remove abstract to activate
abstract contract SparkEthereum_EmptyTest is SparkEthereumTestBase {

    constructor() {
        id                = 'Empty';
        disableExportDiff = true;
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19573528);  // April 3, 2024
        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}
