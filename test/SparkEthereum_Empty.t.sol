// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../src/SparkTestBase.sol';

contract SparkEthereum_EmptyTest is SparkEthereumTestBase {

    constructor() {
        id                = 'Empty';
        disableExportDiff = true;
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18707048);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}
