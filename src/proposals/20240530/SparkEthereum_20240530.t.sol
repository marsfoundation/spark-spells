// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';

contract SparkEthereum_20240530Test is SparkEthereumTestBase {

    address public constant GNOSIS_PAYLOAD = address(0);  // TODO

    Domain       mainnet;
    GnosisDomain gnosis;

    constructor() {
        id = '20240530';
    }

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        gnosis  = new GnosisDomain(getChain('gnosis_chain'), mainnet);

        mainnet.rollFork(19918271);  // May 21, 2024
        gnosis.rollFork(34058083);   // May 21, 2024

        //mainnet.selectFork();

        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}
