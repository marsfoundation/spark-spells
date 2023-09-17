// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGnosis_20230927 } from './SparkGnosis_20230927.sol';

contract SparkGnosis_20230927Test is SparkGnosisTestBase {

    constructor() {
        id = '20230927';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        // TODO Test the instance is empty

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        // TODO Test addition of e-mode and new assets
    }

}
