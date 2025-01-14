// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { SparkTestBase } from 'src/SparkTestBase.sol';
import { ChainIdUtils } from 'src/libraries/ChainId.sol';

contract SparkEthereum_20250123Test is SparkTestBase {
    constructor() {
        id = '20250123';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock: 21623035,
            baseForkBlock:    25036049,
            gnosisForkBlock:  38037888
        });
        deployPayloads();
    }

    function test_ETHEREUM_Sparklend_USDSOnboarding() public onChain(ChainIdUtils.Ethereum()) {}

    function test_ETHEREUM_SLL_USDSRateLimits() public onChain(ChainIdUtils.Ethereum()) {}

    function test_ETHEREUM_SLL_USDCRateLimits() public onChain(ChainIdUtils.Ethereum()) {}

    function test_ETHEREUM_SLL_PrimeAUSDSRateLimits() public onChain(ChainIdUtils.Ethereum()) {}
}
