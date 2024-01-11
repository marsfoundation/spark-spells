// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkGnosis_20240110 } from './SparkGnosis_20240110.sol';

contract SparkGnosis_20240110Test is SparkGnosisTestBase {

    address constant POOL_IMPLEMENTATION_OLD = 0x026a5B6114431d8F3eF2fA0E1B2EDdDccA9c540E;
    address constant POOL_IMPLEMENTATION_NEW = 0xa8fC41696F2a230b03F77d258Db39069e9e55F56;

    constructor() {
        id = '20240110';
    }

    function setUp() public {
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl, 31894743);  // Jan 11, 2024
        payload = 0x670C94430E54D498F4e23BA1F6F2352e735c1d87;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function test_poolUpgrade() public {
        vm.prank(address(poolAddressesProvider));
        assertEq(IProxyLike(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_OLD);
        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), 0);

        GovHelpers.executePayload(vm, payload, executor);

        vm.prank(address(poolAddressesProvider));
        assertEq(IProxyLike(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_NEW);
        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), 0);
    }

}
