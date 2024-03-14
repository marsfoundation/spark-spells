// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

contract SparkEthereum_20240320Test is SparkEthereumTestBase {

    constructor() {
        id = '20240320';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testCapAutomatorConfiguration() public {
        _assertSupplyCapConfig({
            asset:            WBTC,
            max:              5_000,
            gap:              500,
            increaseCooldown: 12 hours
        });

        GovHelpers.executePayload(vm, payload, executor);

        _assertSupplyCapConfig({
            asset:            WBTC,
            max:              6_000,
            gap:              500,
            increaseCooldown: 12 hours
        });
    }

}
