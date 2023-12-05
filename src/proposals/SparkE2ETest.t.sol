// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../SparkTestBase.sol';

contract SparkEthereum_E2ETest is SparkEthereumTestBase {

    constructor() {
        id = '20231129';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18707048);
        payload = 0x68a075249fA77173b8d1B92750c9920423997e2B;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}
