// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGnosis_20231115 } from './SparkGnosis_20231115.sol';

contract SparkGnosis_20231115Test is SparkGnosisTestBase {

    constructor() {
        id = '20231115';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl);
        payload = 0x41709f51E59ddbEbF37cE95257b2E4f2884a45F8;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}
