// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

contract SparkEthereum_20240417Test is SparkEthereumTestBase {

    address public constant POOL_IMPLEMENTATION_OLD = Ethereum.POOL_IMPL;
    address public constant POOL_IMPLEMENTATION_NEW = 0x5aE329203E00f76891094DcfedD5Aca082a50e1b;
    address public constant FREEZER_MOM_OLD         = Ethereum.FREEZER_MOM;
    address public constant FREEZER_MOM_NEW         = 0x237e3985dD7E373F2ec878EC1Ac48A228Cf2e7a3;
    address public constant FREEZER_MULTISIG        = 0x0;  // TODO

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

    function test_freezerMomDeployAndConfiguration() public {
        IFreezerMom freezerMom = IFreezerMom(FREEZER_MOM_NEW);
        
        assertEq(freezerMom.poolConfigurator(),      address(poolConfigurator));
        assertEq(freezerMom.pool(),                  address(pool));
        assertEq(freezerMom.owner(),                 executor);
        assertEq(freezerMom.authority(),             address(0));
        assertEq(freezerMom.wards(FREEZER_MULTISIG), 0);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(freezerMom.poolConfigurator(),      address(poolConfigurator));
        assertEq(freezerMom.pool(),                  address(pool));
        assertEq(freezerMom.owner(),                 executor);
        assertEq(freezerMom.authority(),             Ethereum.CHIEF);
        assertEq(freezerMom.wards(FREEZER_MULTISIG), 1);
    }

    function test_aclChanges() public {
        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM_OLD), true);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM_OLD), true);
        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM_NEW), false);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM_NEW), false);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM_OLD), false);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM_OLD), false);
        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM_NEW), true);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM_NEW), true);
    }

}
