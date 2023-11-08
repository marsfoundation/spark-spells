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
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}
