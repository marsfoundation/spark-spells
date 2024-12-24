// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './ProtocolV3TestBase.sol';

import { Address } from './libraries/Address.sol';

import { InitializableAdminUpgradeabilityProxy } from "sparklend-v1-core/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol";
import { IACLManager }                           from 'sparklend-v1-core/contracts/interfaces/IACLManager.sol';
import { IPoolAddressesProviderRegistry }        from 'sparklend-v1-core/contracts/interfaces/IPoolAddressesProviderRegistry.sol';
import { IPoolConfigurator }                     from 'sparklend-v1-core/contracts/interfaces/IPoolConfigurator.sol';
import { IScaledBalanceToken }                   from "sparklend-v1-core/contracts/interfaces/IScaledBalanceToken.sol";
import { IncentivizedERC20 }                     from 'sparklend-v1-core/contracts/protocol/tokenization/base/IncentivizedERC20.sol';
import { ReserveConfiguration }                  from 'sparklend-v1-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import { WadRayMath }                            from "sparklend-v1-core/contracts/protocol/libraries/math/WadRayMath.sol";

import { Base } from 'spark-address-registry/Base.sol';

import { ISparkLendFreezerMom } from 'sparklend-freezer/interfaces/ISparkLendFreezerMom.sol';

import { IMetaMorpho, MarketParams, PendingUint192, Id } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';
import { MarketParamsLib }                               from 'lib/metamorpho/lib/morpho-blue/src/libraries/MarketParamsLib.sol';

import { IExecutor } from 'lib/spark-gov-relay/src/interfaces/IExecutor.sol';

import { IRateLimits } from "spark-alm-controller/src/interfaces/IRateLimits.sol";

import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";
import { OptimismBridgeTesting } from "xchain-helpers/testing/bridges/OptimismBridgeTesting.sol";
import { AMBBridgeTesting }      from "xchain-helpers/testing/bridges/AMBBridgeTesting.sol";
import { CCTPBridgeTesting }     from "xchain-helpers/testing/bridges/CCTPBridgeTesting.sol";
import { Bridge }                from "xchain-helpers/testing/Bridge.sol";

// REPO ARCHITECTURE TODOs
// TODO: Refactor Mock logic for executor to be more realistic, consider fork + prank.

interface IAuthority {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
    function hat() external view returns (address);
    function lock(uint256 amount) external;
    function vote(address[] calldata slate) external;
    function lift(address target) external;
}

interface IExecutable {
    function execute() external;
}

abstract contract SpellRunner is Test {
    using DomainHelpers for Domain;
    using DomainHelpers for StdChains.Chain;

    enum BridgeType {
        OPTIMISM,
        CCTP,
        GNOSIS
    }

    struct ChainSpellMetadata{
      address                        payload;
      IExecutor                      executor;
      Domain                         domain;
      /// @notice on mainnet: empty
      /// on L2s: mainnet address of the bridge that'll include txs in the L2
      /// there can be multiple bridges for a given chain, such as canonical OP
      /// bridge and CCTP USDC-specific bridge
      Bridge[]                       bridges;
      BridgeType[]                   bridgeTypes;
      // @notice coupled to SparklendTests, zero on chains where sparklend is not present
      IPoolAddressesProviderRegistry sparklendPooAddressProviderRegistry;
    }

    mapping(ChainId chainId => ChainSpellMetadata chainSpellMetadata) internal chainSpellMetadata;

    ChainId[] internal allChains;
    string internal    id;

    modifier onChain(ChainId chainId) virtual {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);
        chainSpellMetadata[chainId].domain.selectFork();
        _;
        chainSpellMetadata[currentChain].domain.selectFork();
    }

    /// @dev to be called in setUp
    function setupDomains(uint256 mainnetForkBlock, uint256 baseForkBlock, uint256 gnosisForkBlock) internal {
        chainSpellMetadata[ChainIdUtils.Ethereum()].domain = getChain("mainnet").createFork(mainnetForkBlock);
        chainSpellMetadata[ChainIdUtils.Base()].domain     = getChain("base").createFork(baseForkBlock);
        chainSpellMetadata[ChainIdUtils.Gnosis()].domain   = getChain("gnosis_chain").createFork(gnosisForkBlock);

        chainSpellMetadata[ChainIdUtils.Ethereum()].executor = IExecutor(Ethereum.SPARK_PROXY);
        chainSpellMetadata[ChainIdUtils.Base()].executor     = IExecutor(Base.SPARK_EXECUTOR);
        chainSpellMetadata[ChainIdUtils.Gnosis()].executor   = IExecutor(Gnosis.AMB_EXECUTOR);

        chainSpellMetadata[ChainIdUtils.Base()].bridges.push(
            OptimismBridgeTesting.createNativeBridge(
                chainSpellMetadata[ChainIdUtils.Ethereum()].domain,
                chainSpellMetadata[ChainIdUtils.Base()].domain
        ));
        chainSpellMetadata[ChainIdUtils.Base()].bridgeTypes.push(BridgeType.OPTIMISM);

        chainSpellMetadata[ChainIdUtils.Ethereum()].sparklendPooAddressProviderRegistry = IPoolAddressesProviderRegistry(Ethereum.POOL_ADDRESSES_PROVIDER_REGISTRY);
        chainSpellMetadata[ChainIdUtils.Gnosis()].sparklendPooAddressProviderRegistry   = IPoolAddressesProviderRegistry(Gnosis.POOL_ADDRESSES_PROVIDER_REGISTRY);

        allChains.push(ChainIdUtils.Ethereum());
        allChains.push(ChainIdUtils.Base());
        allChains.push(ChainIdUtils.Gnosis());
    }

    function spellIdentifier(ChainId chainId) private view returns(string memory){
        string memory slug            = string(abi.encodePacked("Spark", chainId.toDomainString(), "_", id));
        string memory spellIdentifier = string(abi.encodePacked(slug, ".sol:", slug));
        return spellIdentifier;
    }

    function deployPayload(ChainId chainId) internal onChain(chainId) returns(address) {
        return deployCode(spellIdentifier(chainId));
    }

    function deployPayloads() internal {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId id = ChainIdUtils.fromDomain(chainSpellMetadata[allChains[i]].domain);
            string memory spellIdentifier = spellIdentifier(id);
            try vm.getCode(spellIdentifier) {
                chainSpellMetadata[id].payload = deployPayload(id);
            } catch {
                console.log("skipping spell deployment for network: ", id.toDomainString());
            }
        }
    }

    /// @dev takes care to revert the selected fork to what was chosen before
    function executeAllPayloadsAndBridges() internal {
        // only execute mainnet payload
        executeMainnetPayload();
        // then use bridges to execute other chains' payloads
        relayMessageOverBridges();
    }

    /// @dev bridge contracts themselves are stored on mainnet
    function relayMessageOverBridges() private onChain(ChainIdUtils.Ethereum()) {
        for (uint256 i = 0; i < allChains.length; i++) {
            ChainId id = ChainIdUtils.fromDomain(chainSpellMetadata[allChains[i]].domain);
            for (uint256 j = 0; j < chainSpellMetadata[id].bridges.length ; j++){
                _executeBridge(chainSpellMetadata[id].bridges[j], chainSpellMetadata[id].bridgeTypes[j]);
            }
        }
    }

    function _executeBridge(Bridge storage bridge, BridgeType bridgeType) private {
        if (bridgeType == BridgeType.OPTIMISM) {
            OptimismBridgeTesting.relayMessagesToDestination(bridge, false);
            OptimismBridgeTesting.relayMessagesToSource(bridge, false);
        } else if (bridgeType == BridgeType.CCTP) {
            CCTPBridgeTesting.relayMessagesToDestination(bridge, false);
            CCTPBridgeTesting.relayMessagesToSource(bridge, false);
        } else if (bridgeType == BridgeType.GNOSIS) {
            AMBBridgeTesting.relayMessagesToDestination(bridge, false);
            AMBBridgeTesting.relayMessagesToSource(bridge, false);
        }
    }

    function executeL2PayloadsFromBridges() private onChain(ChainIdUtils.Ethereum()) {
        // Base
        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        IExecutor(Base.SPARK_EXECUTOR).execute(IExecutor(Base.SPARK_EXECUTOR).actionsSetCount() - 1);
        // Gnosis: TODO
    }

    function executeMainnetPayload() internal onChain(ChainIdUtils.Ethereum()){
        address payloadAddress = chainSpellMetadata[ChainIdUtils.Ethereum()].payload;
        IExecutor executor     = chainSpellMetadata[ChainIdUtils.Ethereum()].executor;
        require(Address.isContract(payloadAddress), "PAYLOAD IS NOT A CONTRACT");

        vm.prank(Ethereum.PAUSE_PROXY);
        (bool success,) = address(executor).call(abi.encodeWithSignature(
            'exec(address,bytes)',
            payloadAddress,
            abi.encodeWithSignature('execute()')
        ));
        require(success, "FAILED TO EXECUTE PAYLOAD");
    }
}

/// @dev assertions that make sense to run on every chain where a spark spell
/// can be executed
abstract contract CommonSpellAssertions is SpellRunner {
    function test_ETHEREUM_PayloadBytecodeMatches() internal {
        testPayloadBytecodeMatches(ChainIdUtils.Ethereum());
    }

    function test_BASE_PayloadBytecodeMatches() internal {
        testPayloadBytecodeMatches(ChainIdUtils.Base());
    }

    function test_GNOSIS_PayloadBytecodeMatches() internal {
        testPayloadBytecodeMatches(ChainIdUtils.Gnosis());
    }

    function testPayloadBytecodeMatches(ChainId chainId) internal onChain(chainId) {
        address actualPayload = chainSpellMetadata[chainId].payload;
        vm.skip(actualPayload == address(0));
        require(Address.isContract(actualPayload), "PAYLOAD IS NOT A CONTRACT");
        address expectedPayload = deployPayload(chainId);

        uint256 expectedBytecodeSize = expectedPayload.code.length;
        uint256 actualBytecodeSize   = actualPayload.code.length;

        uint256 metadataLength = _getBytecodeMetadataLength(expectedPayload);
        assertTrue(metadataLength <= expectedBytecodeSize);
        expectedBytecodeSize -= metadataLength;

        metadataLength = _getBytecodeMetadataLength(actualPayload);
        assertTrue(metadataLength <= actualBytecodeSize);
        actualBytecodeSize -= metadataLength;

        assertEq(actualBytecodeSize, expectedBytecodeSize);

        uint256 size = actualBytecodeSize;
        uint256 expectedHash;
        uint256 actualHash;

        assembly {
            let ptr := mload(0x40)

            extcodecopy(expectedPayload, ptr, 0, size)
            expectedHash := keccak256(ptr, size)

            extcodecopy(actualPayload, ptr, 0, size)
            actualHash := keccak256(ptr, size)
        }

        assertEq(actualHash, expectedHash);
    }

    function _getBytecodeMetadataLength(address a) internal view returns (uint256 length) {
        // The Solidity compiler encodes the metadata length in the last two bytes of the contract bytecode.
        assembly {
            let ptr  := mload(0x40)
            let size := extcodesize(a)
            if iszero(lt(size, 2)) {
                extcodecopy(a, ptr, sub(size, 2), 2)
                length := mload(ptr)
                length := shr(240, length)
                length := add(length, 2)  // The two bytes used to specify the length are not counted in the length
            }
            // Return zero if the bytecode is shorter than two bytes.
        }
    }
}

/// @dev assertions specific to sparklend, which are not run on chains where
/// it is not deployed
abstract contract SparklendTests is ProtocolV3TestBase, SpellRunner {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using DomainHelpers for StdChains.Chain;
    using DomainHelpers for Domain;

    bool internal disableExportDiff;
    bool internal disableE2E;

    /// @notice local to market currently under test
    IACLManager                    internal aclManager;
    /// @notice local to market currently under test
    IPool                          internal pool;
    /// @notice local to market currently under test
    IPoolConfigurator              internal poolConfigurator;
    /// @notice local to market currently under test
    IAaveOracle                    internal priceOracle;

    modifier onChain(ChainId chainId) override virtual {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);
        chainSpellMetadata[chainId].domain.selectFork();
        // this mimics the logic of legacy spells where they had a
        // `loadPoolContext` call in the setup of every test contract involving
        // sparklend, while not overriding explicit pool context setup if on
        // nested modifier invocations
        if(address(pool) == address(0)){
            loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        }
        _;
        chainSpellMetadata[currentChain].domain.selectFork();
    }

    function loadPoolContext(address poolProvider) internal {
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(poolProvider);
        pool                  = IPool(poolAddressesProvider.getPool());
        poolConfigurator      = IPoolConfigurator(poolAddressesProvider.getPoolConfigurator());
        aclManager            = IACLManager(poolAddressesProvider.getACLManager());
        priceOracle           = IAaveOracle(poolAddressesProvider.getPriceOracle());
    }

    function test_ETHEREUM_SpellExecutionDiff() public {
        testSpellExecutionDiff(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_SpellExecutionDiff() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        testSpellExecutionDiff(ChainIdUtils.Gnosis());
    }

    function testSpellExecutionDiff(ChainId chainId) onChain(chainId) internal {
        address[] memory poolProviders = _getPoolAddressesProviderRegistry().getAddressesProvidersList();
        string memory prefix = string(abi.encodePacked(id, '-', chainId.toDomainString()));

        for (uint256 i = 0; i < poolProviders.length; i++) {
            loadPoolContext(poolProviders[i]);

            createConfigurationSnapshot(
                string(abi.encodePacked(prefix, '-', vm.toString(address(pool)), '-pre')),
                pool
            );
        }

        executeAllPayloadsAndBridges();

        for (uint256 i = 0; i < poolProviders.length; i++) {
            loadPoolContext(poolProviders[i]);

            createConfigurationSnapshot(
                string(abi.encodePacked(prefix, '-', vm.toString(address(pool)), '-post')),
                pool
            );

            if (!disableExportDiff) {
                diffReports(
                    string(abi.encodePacked(prefix, '-', vm.toString(address(pool)), '-pre')),
                    string(abi.encodePacked(prefix, '-', vm.toString(address(pool)), '-post'))
                );
            }
        }
    }

    function test_ETHEREUM_E2E() public {
        testE2E(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_E2E() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        testE2E(ChainIdUtils.Gnosis());
    }

    function testE2E(ChainId chainId) internal onChain(chainId) {
        if (disableE2E) return;

        address[] memory poolProviders = _getPoolAddressesProviderRegistry().getAddressesProvidersList();

        for (uint256 i = 0; i < poolProviders.length; i++) {
            loadPoolContext(poolProviders[i]);
            e2eTest(pool);
        }

        // the full payload + bridges causes a MemoryOOG error on ethereum.
        // This is a workaround, skipping the bridging to consume less
        // resources
        if(chainId == ChainIdUtils.Ethereum()){
            executeMainnetPayload();
        } else {
            executeAllPayloadsAndBridges();
        }

        for (uint256 i = 0; i < poolProviders.length; i++) {
            loadPoolContext(poolProviders[i]);
            e2eTest(pool);
        }
    }

    function test_ETHEREUM_TokenImplementationsMatch() public {
        testTokenImplementationsMatch(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_TokenImplementationsMatch() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        testTokenImplementationsMatch(ChainIdUtils.Gnosis());
    }

    function testTokenImplementationsMatch(ChainId chainId) internal onChain(chainId) {
        // This test is to avoid a footgun where the token implementations are upgraded (possibly in an emergency) and
        // the config engine is not redeployed to use the new implementation. As a general rule all reserves should
        // use the same implementation for AToken, StableDebtToken and VariableDebtToken.
        executeAllPayloadsAndBridges();

        address[] memory reserves = pool.getReservesList();
        assertGt(reserves.length, 0);

        DataTypes.ReserveData memory data = pool.getReserveData(reserves[0]);
        address aTokenImpl            = getImplementation(address(poolConfigurator), data.aTokenAddress);
        address stableDebtTokenImpl   = getImplementation(address(poolConfigurator), data.stableDebtTokenAddress);
        address variableDebtTokenImpl = getImplementation(address(poolConfigurator), data.variableDebtTokenAddress);

        for (uint256 i = 1; i < reserves.length; i++) {
            DataTypes.ReserveData memory expectedData = pool.getReserveData(reserves[i]);

            assertEq(getImplementation(address(poolConfigurator), expectedData.aTokenAddress),            aTokenImpl);
            assertEq(getImplementation(address(poolConfigurator), expectedData.stableDebtTokenAddress),   stableDebtTokenImpl);
            assertEq(getImplementation(address(poolConfigurator), expectedData.variableDebtTokenAddress), variableDebtTokenImpl);
        }
    }

    function test_ETHEREUM_Oracles() public {
        testOracles(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_Oracles() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        testOracles(ChainIdUtils.Gnosis());
    }

    function testOracles(ChainId chainId) internal onChain(chainId) {
        _validateOracles();

        executeAllPayloadsAndBridges();

        _validateOracles();
    }

    function test_ETHEREUM_AllReservesSeeded() public {
        testAllReservesSeeded(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_AllReservesSeeded() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        testAllReservesSeeded(ChainIdUtils.Gnosis());
    }

    function testAllReservesSeeded(ChainId chainId) internal onChain(chainId) {
        executeAllPayloadsAndBridges();

        address[] memory reserves = pool.getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            IERC20 aToken = IERC20(pool.getReserveData(reserves[i]).aTokenAddress);
            require(aToken.totalSupply() >= 1e6, 'RESERVE_NOT_SEEDED');
        }
    }

    function _validateOracles() internal view {
        address[] memory reserves = pool.getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            require(priceOracle.getAssetPrice(reserves[i]) >= 0.5e8,      '_validateAssetSourceOnOracle() : INVALID_PRICE_TOO_LOW');
            require(priceOracle.getAssetPrice(reserves[i]) <= 1_000_000e8,'_validateAssetSourceOnOracle() : INVALID_PRICE_TOO_HIGH');
        }
    }

    function getImplementation(address admin, address proxy) internal returns (address) {
        vm.prank(admin);
        return InitializableAdminUpgradeabilityProxy(payable(proxy)).implementation();
    }

    function _getPoolAddressesProviderRegistry() internal view returns(IPoolAddressesProviderRegistry registry ){
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);
        registry = chainSpellMetadata[currentChain].sparklendPooAddressProviderRegistry;
        require(address(registry) != address(0), "Sparklend/executing on unknown chain");
    }
}

/// @dev assertions specific to mainnet
/// TODO: separate tests related to sparklend from the rest (eg: morpho)
///       also separate mainnet-specific sparklend tests from those we should
///       run on Gnosis as well
abstract contract SparkEthereumTests is SparklendTests {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using WadRayMath for uint256;

    IAuthority           internal authority;
    ISparkLendFreezerMom internal freezerMom;
    ICapAutomator        internal capAutomator;

    constructor() {
        authority    = IAuthority(Ethereum.CHIEF);
        freezerMom   = ISparkLendFreezerMom(Ethereum.FREEZER_MOM);
        capAutomator = ICapAutomator(Ethereum.CAP_AUTOMATOR);
    }

    function test_ETHEREUM_FreezerMom() public onChain(ChainIdUtils.Ethereum()){
        uint256 snapshot = vm.snapshot();

        _runFreezerMomTests();

        vm.revertTo(snapshot);
        executeAllPayloadsAndBridges();

        _runFreezerMomTests();
    }

    function test_ETHEREUM_RewardsConfiguration() public onChain(ChainIdUtils.Ethereum()){
        _runRewardsConfigurationTests();

        executeAllPayloadsAndBridges();

        _runRewardsConfigurationTests();
    }

    function test_ETHEREUM_CapAutomator() public onChain(ChainIdUtils.Ethereum()){
        uint256 snapshot = vm.snapshot();

        _runCapAutomatorTests();

        vm.revertTo(snapshot);
        executeAllPayloadsAndBridges();

        _runCapAutomatorTests();
    }

    function _runRewardsConfigurationTests() internal {
        address[] memory reserves = pool.getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(reserves[i]);

            assertEq(address(IncentivizedERC20(reserveData.aTokenAddress).getIncentivesController()),            Ethereum.INCENTIVES);
            assertEq(address(IncentivizedERC20(reserveData.variableDebtTokenAddress).getIncentivesController()), Ethereum.INCENTIVES);
        }
    }

    function _assertFrozen(address asset, bool frozen) internal {
        assertEq(pool.getConfiguration(asset).getFrozen(), frozen);
    }

    function _assertPaused(address asset, bool paused) internal {
        assertEq(pool.getConfiguration(asset).getPaused(), paused);
    }

    function _voteAndCast(address _spell) internal {
        address mkrWhale = makeAddr("mkrWhale");
        uint256 amount = 1_000_000 ether;

        deal(Ethereum.MKR, mkrWhale, amount);

        vm.startPrank(mkrWhale);
        IERC20(Ethereum.MKR).approve(address(authority), amount);
        authority.lock(amount);

        address[] memory slate = new address[](1);
        slate[0] = _spell;
        authority.vote(slate);

        vm.roll(block.number + 1);

        authority.lift(_spell);

        vm.stopPrank();

        assertEq(authority.hat(), _spell);

        vm.prank(makeAddr("randomUser"));
        IExecutable(_spell).execute();
    }

    function _runFreezerMomTests() internal {
        // Sanity checks - cannot call Freezer Mom unless you have the hat
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.freezeMarket(Ethereum.DAI, true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.freezeAllMarkets(true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.pauseMarket(Ethereum.DAI, true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.pauseAllMarkets(true);

        _assertFrozen(Ethereum.DAI,  false);
        _assertFrozen(Ethereum.WETH, false);
        _voteAndCast(Ethereum.SPELL_FREEZE_DAI);
        _assertFrozen(Ethereum.DAI,  true);
        _assertFrozen(Ethereum.WETH, false);

        _voteAndCast(Ethereum.SPELL_FREEZE_ALL);
        _assertFrozen(Ethereum.DAI,  true);
        _assertFrozen(Ethereum.WETH, true);

        _assertPaused(Ethereum.DAI,  false);
        _assertPaused(Ethereum.WETH, false);
        _voteAndCast(Ethereum.SPELL_PAUSE_DAI);
        _assertPaused(Ethereum.DAI,  true);
        _assertPaused(Ethereum.WETH, false);

        _voteAndCast(Ethereum.SPELL_PAUSE_ALL);
        _assertPaused(Ethereum.DAI,  true);
        _assertPaused(Ethereum.WETH, true);
    }

    function _runCapAutomatorTests() internal {
        address[] memory reserves = pool.getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            _assertAutomatedCapsUpdate(reserves[i]);
        }
    }

    function _assertAutomatedCapsUpdate(address asset) internal {
        DataTypes.ReserveData memory reserveDataBefore = pool.getReserveData(asset);

        uint256 supplyCapBefore = reserveDataBefore.configuration.getSupplyCap();
        uint256 borrowCapBefore = reserveDataBefore.configuration.getBorrowCap();

        (,,,,uint48 supplyCapLastIncreaseTime) = capAutomator.supplyCapConfigs(asset);
        (,,,,uint48 borrowCapLastIncreaseTime) = capAutomator.borrowCapConfigs(asset);

        capAutomator.exec(asset);

        DataTypes.ReserveData memory reserveDataAfter = pool.getReserveData(asset);

        uint256 supplyCapAfter = reserveDataAfter.configuration.getSupplyCap();
        uint256 borrowCapAfter = reserveDataAfter.configuration.getBorrowCap();

        uint48 max;
        uint48 gap;
        uint48 cooldown;

        (max, gap, cooldown,,) = capAutomator.supplyCapConfigs(asset);

        if (max > 0) {
            uint256 currentSupply = (IScaledBalanceToken(reserveDataAfter.aTokenAddress).scaledTotalSupply() + uint256(reserveDataAfter.accruedToTreasury))
                .rayMul(reserveDataAfter.liquidityIndex)
                / 10 ** IERC20(reserveDataAfter.aTokenAddress).decimals();

            uint256 expectedSupplyCap = uint256(max) < currentSupply + uint256(gap)
                ? uint256(max)
                : currentSupply + uint256(gap);

            if (supplyCapLastIncreaseTime + cooldown > block.timestamp && supplyCapBefore < expectedSupplyCap) {
                assertEq(supplyCapAfter, supplyCapBefore);
            } else {
                assertEq(supplyCapAfter, expectedSupplyCap);
            }
        } else {
            assertEq(supplyCapAfter, supplyCapBefore);
        }

        (max, gap, cooldown,,) = capAutomator.borrowCapConfigs(asset);

        if (max > 0) {
            uint256 currentBorrows = IERC20(reserveDataAfter.variableDebtTokenAddress).totalSupply() / 10 ** IERC20(reserveDataAfter.variableDebtTokenAddress).decimals();

            uint256 expectedBorrowCap = uint256(max) < currentBorrows + uint256(gap)
                ? uint256(max)
                : currentBorrows + uint256(gap);

            if (borrowCapLastIncreaseTime + cooldown > block.timestamp && borrowCapBefore < expectedBorrowCap) {
                assertEq(borrowCapAfter, borrowCapBefore);
            } else {
                assertEq(borrowCapAfter, expectedBorrowCap);
            }
        } else {
            assertEq(borrowCapAfter, borrowCapBefore);
        }
    }

    function _assertBorrowCapConfig(address asset, uint48 max, uint48 gap, uint48 increaseCooldown) internal {
        (uint48 _max, uint48 _gap, uint48 _increaseCooldown,,) = capAutomator.borrowCapConfigs(asset);
        assertEq(_max,              max);
        assertEq(_gap,              gap);
        assertEq(_increaseCooldown, increaseCooldown);
    }

    function _assertBorrowCapConfigNotSet(address asset) internal {
        (uint48 _max, uint48 _gap, uint48 _increaseCooldown,,) = capAutomator.borrowCapConfigs(asset);
        assertEq(_max,              0);
        assertEq(_gap,              0);
        assertEq(_increaseCooldown, 0);
    }

    function _assertSupplyCapConfig(address asset, uint48 max, uint48 gap, uint48 increaseCooldown) internal {
        (uint48 _max, uint48 _gap, uint48 _increaseCooldown,,) = capAutomator.supplyCapConfigs(asset);
        assertEq(_max,              max);
        assertEq(_gap,              gap);
        assertEq(_increaseCooldown, increaseCooldown);
    }

    function _assertSupplyCapConfigNotSet(address asset) internal {
        (uint48 _max, uint48 _gap, uint48 _increaseCooldown,,) = capAutomator.supplyCapConfigs(asset);
        assertEq(_max,              0);
        assertEq(_gap,              0);
        assertEq(_increaseCooldown, 0);
    }

    function _assertMorphoCap(
        MarketParams memory _config,
        uint256             _currentCap,
        bool                _hasPending,
        uint256             _pendingCap
    ) internal {
        Id id = MarketParamsLib.id(_config);
        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).config(id).cap, _currentCap);
        PendingUint192 memory pendingCap = IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).pendingCap(id);
        if (_hasPending) {
            assertEq(pendingCap.value,   _pendingCap);
            assertGt(pendingCap.validAt, 0);
        } else {
            assertEq(pendingCap.value,   0);
            assertEq(pendingCap.validAt, 0);
        }
    }

    function _assertMorphoCap(
        MarketParams memory _config,
        uint256             _currentCap,
        uint256             _pendingCap
    ) internal {
        _assertMorphoCap(_config, _currentCap, true, _pendingCap);
    }

    function _assertMorphoCap(
        MarketParams memory _config,
        uint256             _currentCap
    ) internal {
        _assertMorphoCap(_config, _currentCap, false, 0);
    }
}

// TODO: expand on this on https://github.com/marsfoundation/spark-spells/issues/65
abstract contract AdvancedLiquidityManagementTests is SpellRunner {
   function _assertRateLimit(
       bytes32 key,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);
        IRateLimits rateLimitsContract;
        if(currentChain == ChainIdUtils.Ethereum()) rateLimitsContract = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        else if(currentChain == ChainIdUtils.Base()) rateLimitsContract = IRateLimits(Base.ALM_RATE_LIMITS);
        else require(false, "ALM/executing on unknown chain");

        IRateLimits.RateLimitData memory rateLimit = rateLimitsContract.getRateLimitData(key);
        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  maxAmount);
        assertEq(rateLimit.lastUpdated, block.timestamp);
    }
}

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specifictest contracts
abstract contract SparkTestBase is AdvancedLiquidityManagementTests, SparkEthereumTests, CommonSpellAssertions {
    using DomainHelpers for StdChains.Chain;
    using DomainHelpers for Domain;

    // cant really instruct the compiler to simply use the SparklendTests
    // implementation, so I copied it.
    modifier onChain(ChainId chainId) override(SparklendTests, SpellRunner) {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);
        chainSpellMetadata[chainId].domain.selectFork();
        if(address(pool) == address(0)){
            loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        }
        _;
        chainSpellMetadata[currentChain].domain.selectFork();
    }
}
