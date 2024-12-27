// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { StdChains } from 'forge-std/StdChains.sol';
import { IERC20 }   from 'forge-std/interfaces/IERC20.sol';

import { InitializableAdminUpgradeabilityProxy } from "sparklend-v1-core/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol";
import { IACLManager }                           from 'sparklend-v1-core/contracts/interfaces/IACLManager.sol';
import { IPoolAddressesProviderRegistry }        from 'sparklend-v1-core/contracts/interfaces/IPoolAddressesProviderRegistry.sol';
import { ReserveConfiguration }                  from 'sparklend-v1-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import { IPoolConfigurator }                     from 'sparklend-v1-core/contracts/interfaces/IPoolConfigurator.sol';

import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";

import {
    ProtocolV3TestBase,
    DataTypes,
    IPool,
    IAaveOracle,
    IPoolAddressesProvider
} from './ProtocolV3TestBase.sol';

import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";
import { SpellRunner }           from './SpellRunner.sol';
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

