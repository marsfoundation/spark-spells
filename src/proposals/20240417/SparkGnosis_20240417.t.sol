// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

contract SparkGnosis_20240417Test is SparkGnosisTestBase {

    address public constant POOL_IMPLEMENTATION_OLD = Gnosis.POOL_IMPL;
    address public constant POOL_IMPLEMENTATION_NEW = 0xCF86A65779e88bedfF0319FE13aE2B47358EB1bF;

    constructor() {
        id = '20240417';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl, 33352951);  // April 9, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function test_poolUpgrade() public {
        vm.prank(address(poolAddressesProvider));
        assertEq(IProxyLike(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_OLD);
        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), 0);  // This doesn't really need to be checked anymore as it was patched in code, but we have it for good measure

        GovHelpers.executePayload(vm, payload, executor);

        vm.prank(address(poolAddressesProvider));
        assertEq(IProxyLike(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_NEW);
        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), 0);
    }

}
