// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import {SparkEthereumTestBase, ReserveConfig} from 'src/SparkTestBase.sol';

contract SparkEthereum_20241128Test is SparkEthereumTestBase {

    constructor() {
        id = '20241128';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 21231255);  // Nov 20, 2024
        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
        payload = deployPayload();
    }

    function testWBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory wbtcConfig         = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold, 65_00);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        wbtcConfig.liquidationThreshold        = 60_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
    }
}
