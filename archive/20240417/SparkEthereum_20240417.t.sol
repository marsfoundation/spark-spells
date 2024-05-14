// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';

interface IIRM {
    function RATE_SOURCE() external view returns (address);
}

interface IRateSource {
    function getAPR() external view returns (int256);
}

interface PotLike {
    function drip() external;
    function file(bytes32 what, uint256 data) external;
}

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

    address public constant GNOSIS_PAYLOAD = 0xa2915822472377C7EF913D5E4D149891FEe4999e;

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x883b03288D1827066C57E5db96661aB994Ef3800;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0xE9905C2dCf64F3fBAeE50a81D1844339FC77e812;

    int256 public constant DAI_IRM_SPREAD = 0.009049835548567426118688000e27;

    Domain       mainnet;
    GnosisDomain gnosis;

    constructor() {
        id = '20240417';
    }

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        gnosis  = new GnosisDomain(getChain('gnosis_chain'), mainnet);

        mainnet.rollFork(19695629);  // April 20, 2024
        gnosis.rollFork(33459207);   // April 15, 2024

        mainnet.selectFork();

        payload = 0x151D5fA7B3eD50098fFfDd61DB29cB928aE04C0e;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        vm.startPrank(Ethereum.PAUSE_PROXY);
        PotLike(Ethereum.POT).drip();
        PotLike(Ethereum.POT).file('dsr', 1000000003022265980097387650);
        vm.stopPrank();
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
        
        assertEq(IPool(Gnosis.POOL).getReservesList().length, 4);
        IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).execute(3);
        assertEq(IPool(Gnosis.POOL).getReservesList().length, 8);
    }

    function testDaiInterestRateUpdate() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');

        address rateSource = IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE();
        assertEq(rateSource, IIRM(OLD_DAI_INTEREST_RATE_STRATEGY).RATE_SOURCE());  // Same rate source as before

        int256 potDsrApr = IRateSource(rateSource).getAPR();

        // Approx 10% APY
        assertEq(_getAPY(uint256(potDsrApr)), 0.099999999999999999953897206e27);

        uint256 expectedDaiBaseVariableBorrowRate = uint256(potDsrApr + DAI_IRM_SPREAD);
        assertEq(expectedDaiBaseVariableBorrowRate, 0.104360015496918643049088000e27);

        // Approx 11% APY
        assertEq(_getAPY(expectedDaiBaseVariableBorrowRate), 0.109999999999999999970583056e27);

        _validateInterestRateStrategy(
            daiConfigAfter.interestRateStrategy,
            NEW_DAI_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             1e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        expectedDaiBaseVariableBorrowRate,
                variableRateSlope1:            0,
                variableRateSlope2:            0
            })
        );
    }

}
