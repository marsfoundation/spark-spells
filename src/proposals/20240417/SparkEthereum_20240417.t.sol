// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';

contract SparkEthereum_20240417Test is SparkEthereumTestBase {

    address public constant POOL_IMPLEMENTATION_OLD = Ethereum.POOL_IMPL;
    address public constant POOL_IMPLEMENTATION_NEW = 0x5aE329203E00f76891094DcfedD5Aca082a50e1b;
    address public constant FREEZER_MOM_OLD         = Ethereum.FREEZER_MOM;
    address public constant FREEZER_MOM_NEW         = 0x237e3985dD7E373F2ec878EC1Ac48A228Cf2e7a3;
    address public constant FREEZER_MULTISIG        = 0x44efFc473e81632B12486866AA1678edbb7BEeC3;

    address public constant SPELL_FREEZE_ALL      = 0x9e2890BF7f8D5568Cc9e5092E67Ba00C8dA3E97f;
    address public constant SPELL_FREEZE_DAI      = 0xa2039bef2c5803d66E4e68F9E23a942E350b938c;
    address public constant SPELL_PAUSE_ALL       = 0x425b0de240b4c2DC45979DB782A355D090Dc4d37;
    address public constant SPELL_PAUSE_DAI       = 0xCacB88e39112B56278db25b423441248cfF94241;
    address public constant SPELL_REMOVE_MULTISIG = 0xE47AB4919F6F5459Dcbbfbe4264BD4630c0169A9;

    address public constant GNOSIS_PAYLOAD = address(0);  // TODO

    Domain       mainnet;
    GnosisDomain gnosis;

    constructor() {
        id = '20240417';
    }

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        gnosis  = new GnosisDomain(getChain('gnosis_chain'), mainnet);

        mainnet.rollFork(19616714);  // April 9, 2024
        gnosis.rollFork(33350835);   // April 9, 2024

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
        ISparkLendFreezerMom freezerMom = ISparkLendFreezerMom(FREEZER_MOM_NEW);
        
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
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM_OLD),      true);
        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM_NEW), false);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM_NEW),      false);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM_OLD), false);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM_OLD),      false);
        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM_NEW), true);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM_NEW),      true);
    }

    function testFreezerMom_REMEMBER_TO_REENABLE_AFTER_THIS_SPELL() public {
        uint256 snapshot = vm.snapshot();

        // These will run as normal
        _runFreezerMomTests();

        vm.revertTo(snapshot);
        GovHelpers.executePayload(vm, payload, executor);

        // There are new spells
        freezerMom = ISparkLendFreezerMom(FREEZER_MOM_NEW);

        // Sanity checks - cannot call Freezer Mom unless you have the hat
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.freezeMarket(Ethereum.DAI, true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.freezeAllMarkets(true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.pauseMarket(Ethereum.DAI, true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.pauseAllMarkets(true);

        snapshot = vm.snapshot();

        _assertFrozen(Ethereum.DAI,  false);
        _assertFrozen(Ethereum.WETH, false);
        _voteAndCast(SPELL_FREEZE_DAI);
        _assertFrozen(Ethereum.DAI,  true);
        _assertFrozen(Ethereum.WETH, false);

        _voteAndCast(SPELL_FREEZE_ALL);
        _assertFrozen(Ethereum.DAI,  true);
        _assertFrozen(Ethereum.WETH, true);

        _assertPaused(Ethereum.DAI,  false);
        _assertPaused(Ethereum.WETH, false);
        _voteAndCast(SPELL_PAUSE_DAI);
        _assertPaused(Ethereum.DAI,  true);
        _assertPaused(Ethereum.WETH, false);

        _voteAndCast(SPELL_PAUSE_ALL);
        _assertPaused(Ethereum.DAI,  true);
        _assertPaused(Ethereum.WETH, true);

        vm.revertTo(snapshot);

        _assertFrozen(Ethereum.DAI,  false);
        _assertFrozen(Ethereum.WETH, false);
        vm.prank(FREEZER_MULTISIG);
        freezerMom.freezeMarket(Ethereum.DAI, true);
        _assertFrozen(Ethereum.DAI,  true);
        _assertFrozen(Ethereum.WETH, false);

        vm.prank(FREEZER_MULTISIG);
        freezerMom.freezeAllMarkets(true);
        _assertFrozen(Ethereum.DAI,  true);
        _assertFrozen(Ethereum.WETH, true);

        _assertPaused(Ethereum.DAI,  false);
        _assertPaused(Ethereum.WETH, false);
        vm.prank(FREEZER_MULTISIG);
        freezerMom.pauseMarket(Ethereum.DAI, true);
        _assertPaused(Ethereum.DAI,  true);
        _assertPaused(Ethereum.WETH, false);

        vm.prank(FREEZER_MULTISIG);
        freezerMom.pauseAllMarkets(true);
        _assertPaused(Ethereum.DAI,  true);
        _assertPaused(Ethereum.WETH, true);

        assertEq(freezerMom.wards(FREEZER_MULTISIG), 1);
        _voteAndCast(SPELL_REMOVE_MULTISIG);
        assertEq(freezerMom.wards(FREEZER_MULTISIG), 0);
    }

    function testGnosisSpellExecution() public {
        GovHelpers.executePayload(vm, payload, executor);

        gnosis.selectFork();

        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getActionsSetCount(), 3);

        gnosis.relayFromHost(true);
        skip(2 days);

        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getActionsSetCount(), 4);
        
        assertTrue(GNOSIS_PAYLOAD != address(0));
        vm.expectCall(
            GNOSIS_PAYLOAD,
            abi.encodeWithSignature('execute()')
        );
        IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).execute(3);
    }

}
