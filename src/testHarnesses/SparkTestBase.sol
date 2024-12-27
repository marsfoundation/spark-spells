// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './ProtocolV3TestBase.sol';

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

import { IRateLimits } from "spark-alm-controller/src/interfaces/IRateLimits.sol";

import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { SpellRunner } from './SpellRunner.sol';
import { CommonSpellAssertions } from './CommonSpellAssertions.sol';

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
        _runSpellExecutionDiff(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_SpellExecutionDiff() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        _runSpellExecutionDiff(ChainIdUtils.Gnosis());
    }

    function _runSpellExecutionDiff(ChainId chainId) onChain(chainId) private {
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
        _runE2ETests(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_E2E() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        _runE2ETests(ChainIdUtils.Gnosis());
    }

    function _runE2ETests(ChainId chainId) private onChain(chainId) {
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
        _assertTokenImplementationsMatch(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_TokenImplementationsMatch() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        _assertTokenImplementationsMatch(ChainIdUtils.Gnosis());
    }

    function _assertTokenImplementationsMatch(ChainId chainId) private onChain(chainId) {
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
        _runOraclesTests(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_Oracles() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        _runOraclesTests(ChainIdUtils.Gnosis());
    }

    function _runOraclesTests(ChainId chainId) private onChain(chainId) {
        _validateOracles();

        executeAllPayloadsAndBridges();

        _validateOracles();
    }

    function test_ETHEREUM_AllReservesSeeded() public {
        _assertAllReservesSeeded(ChainIdUtils.Ethereum());
    }

    function test_GNOSIS_AllReservesSeeded() public {
        vm.skip(chainSpellMetadata[ChainIdUtils.Gnosis()].payload == address(0));
        _assertAllReservesSeeded(ChainIdUtils.Gnosis());
    }

    function _assertAllReservesSeeded(ChainId chainId) private onChain(chainId) {
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
