// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { Ownable } from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/Ownable.sol';

import { SparkEthereum_20230816 } from './SparkEthereum_20230816.sol';

contract SparkEthereum_20230816Test is SparkEthereumTestBase {

    address constant internal PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    constructor() {
        id = '20230816';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 17892780);
        payload = 0x60cC45DaB5F0B17789C77d5FE990f1aD80e9DD65;

        // This will be done in the main spell (simulate it here)
        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
        vm.prank(PAUSE_PROXY);
        Ownable(address(poolAddressesProvider)).transferOwnership(address(executor));
    }

}
