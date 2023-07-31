// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { Ownable } from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/Ownable.sol';

import { SparkGoerli_20230816 } from './SparkGoerli_20230816.sol';

contract SparkGoerli_20230816Test is SparkGoerliTestBase {

    address constant internal PAUSE_PROXY = 0x5DCdbD3cCF9B09EAAD03bc5f50fA2B3d3ACA0121;

    constructor() {
        id = '20230816';
    }

    function setUp() public {
        vm.createSelectFork(getChain('goerli').rpcUrl);
        payload = deployPayload();

        // This will be done in the main spell (simulate it here)
        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
        vm.prank(PAUSE_PROXY);
        Ownable(address(poolAddressesProvider)).transferOwnership(address(executor));
    }

}
