// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { Ownable } from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/Ownable.sol';

import { SparkEthereum_20230816 } from './SparkEthereum_20230816.sol';

contract SparkEthereum_20230816Test is SparkEthereumTestBase {

    constructor() {
        id = '20230816';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
        payload = address(new SparkEthereum_20230816());

        // This will be done in the main spell (simulate it here)
        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
        vm.prank(0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB);
        Ownable(address(poolAddressesProvider)).transferOwnership(address(executor));
    }

}
