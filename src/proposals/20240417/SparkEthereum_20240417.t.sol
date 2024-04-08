// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

contract SparkEthereum_20240417Test is SparkEthereumTestBase {

    address public constant POOL_IMPLEMENTATION_OLD = Ethereum.POOL_IMPL;
    address public constant POOL_IMPLEMENTATION_NEW = 0x5aE329203E00f76891094DcfedD5Aca082a50e1b;

    constructor() {
        id = '20240417';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19609702);  // April 8, 2024
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
