// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

contract SparkEthereum_20240306Test is SparkEthereumTestBase {

    address public constant CAP_AUTOMATOR = 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef;

    constructor() {
        id = '20240306';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function test_aclChanges() public {
        assertEq(aclManager.isRiskAdmin(CAP_AUTOMATOR), false);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(aclManager.isRiskAdmin(CAP_AUTOMATOR), true);
    }
}
