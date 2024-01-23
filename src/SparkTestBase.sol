// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './ProtocolV3TestBase.sol';

import { GovHelpers } from './libraries/GovHelpers.sol';

import { InitializableAdminUpgradeabilityProxy } from "aave-v3-core/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol";
import { IACLManager }                           from 'aave-v3-core/contracts/interfaces/IACLManager.sol';
import { IPool }                                 from 'aave-v3-core/contracts/interfaces/IPool.sol';
import { IPoolAddressesProvider }                from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';
import { IPoolAddressesProviderRegistry }        from 'aave-v3-core/contracts/interfaces/IPoolAddressesProviderRegistry.sol';
import { IPoolConfigurator }                     from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';
import { IncentivizedERC20 }                     from 'aave-v3-core/contracts/protocol/tokenization/base/IncentivizedERC20.sol';
import { DataTypes }                             from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';
import { ReserveConfiguration }                  from 'aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';

import { IDaiInterestRateStrategy }    from "./interfaces/IDaiInterestRateStrategy.sol";
import { IDaiJugInterestRateStrategy } from "./interfaces/IDaiJugInterestRateStrategy.sol";
import { ISparkLendFreezerMom }        from './interfaces/ISparkLendFreezerMom.sol';

// REPO ARCHITECTURE TODOs
// TODO: Investigate if aave-address-book can be removed as dep
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

abstract contract SparkTestBase is ProtocolV3TestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    struct DaiInterestStrategyValues {
        address vat;
        address pot;
        bytes32 ilk;
        uint256 baseRateConversion;
        uint256 borrowSpread;
        uint256 supplySpread;
        uint256 maxRate;
        uint256 performanceBonus;
    }

    struct DaiJugInterestStrategyValues {
        address vat;
        address jug;
        bytes32 ilk;
        uint256 baseRateConversion;
        uint256 borrowSpread;
        uint256 supplySpread;
        uint256 maxRate;
        uint256 performanceBonus;
    }

    address internal executor;
    address internal payload;

    string internal domain;
    string internal id;

    bool internal disableExportDiff;
    bool internal disableE2E;

    IACLManager                    internal aclManager;
    IPool                          internal pool;
    IPoolAddressesProvider         internal poolAddressesProvider;
    IPoolAddressesProviderRegistry internal poolAddressesProviderRegistry;
    IPoolConfigurator              internal poolConfigurator;
    IAaveOracle                    internal priceOracle;

    function loadPoolContext(address poolProvider) internal {
        poolAddressesProvider = IPoolAddressesProvider(poolProvider);
        pool                  = IPool(poolAddressesProvider.getPool());
        poolConfigurator      = IPoolConfigurator(poolAddressesProvider.getPoolConfigurator());
        aclManager            = IACLManager(poolAddressesProvider.getACLManager());
        priceOracle           = IAaveOracle(poolAddressesProvider.getPriceOracle());
    }

    function deployPayload() internal returns (address) {
        return deployCode(string(abi.encodePacked('Spark', domain, '_', id, '.sol')));
    }

    function testSpellExecutionDiff() public {
        address[] memory poolProviders = poolAddressesProviderRegistry.getAddressesProvidersList();
        string memory prefix = string(abi.encodePacked(id, '-', domain));

        for (uint256 i = 0; i < poolProviders.length; i++) {
            loadPoolContext(poolProviders[i]);

            createConfigurationSnapshot(
                string(abi.encodePacked(prefix, '-', vm.toString(address(pool)), '-pre')),
                pool
            );
        }

        GovHelpers.executePayload(vm, payload, executor);

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

    function testE2E() public {
        if (disableE2E) return;

        address[] memory poolProviders = poolAddressesProviderRegistry.getAddressesProvidersList();

        for (uint256 i = 0; i < poolProviders.length; i++) {
            loadPoolContext(poolProviders[i]);
            e2eTest(pool);
        }

        GovHelpers.executePayload(vm, payload, executor);

        for (uint256 i = 0; i < poolProviders.length; i++) {
            loadPoolContext(poolProviders[i]);
            e2eTest(pool);
        }
    }

    function testPayloadBytecodeMatches() public {
        address expectedPayload = deployPayload();
        address actualPayload   = payload;

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

    function testTokenImplementationsMatch() public {
        // This test is to avoid a footgun where the token implementations are upgraded (possibly in an emergency) and
        // the config engine is not redeployed to use the new implementation. As a general rule all reserves should
        // use the same implementation for AToken, StableDebtToken and VariableDebtToken.
        GovHelpers.executePayload(vm, payload, executor);

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

    function testOracles() public {
        _validateOracles();

        GovHelpers.executePayload(vm, payload, executor);

        _validateOracles();
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

    function _writeStrategyConfig(string memory strategiesKey, address _strategy) internal override returns (string memory content) {
        try IDefaultInterestRateStrategy(_strategy).getBaseStableBorrowRate() {
            // Default IRS
            content = super._writeStrategyConfig(strategiesKey, _strategy);
        } catch {
            // DAI IRS
            string memory key = vm.toString(_strategy);

            IDaiInterestRateStrategy strategy = IDaiInterestRateStrategy(_strategy);

            vm.serializeUint(key, 'baseRateConversion', strategy.baseRateConversion());
            vm.serializeUint(key, 'borrowSpread',       strategy.borrowSpread());
            vm.serializeUint(key, 'supplySpread',       strategy.supplySpread());
            vm.serializeUint(key, 'maxRate',            strategy.maxRate());

            string memory object = vm.serializeUint(key, 'performanceBonus', strategy.performanceBonus());

            content = vm.serializeString(strategiesKey, key, object);
        }
    }

    function _validateDaiInterestRateStrategy(
        address interestRateStrategyAddress,
        address expectedStrategy,
        DaiInterestStrategyValues memory expectedStrategyValues
    ) internal view {
        IDaiInterestRateStrategy strategy = IDaiInterestRateStrategy(
            interestRateStrategyAddress
        );

        require(
            address(strategy) == expectedStrategy,
            '_validateDaiInterestRateStrategy() : INVALID_STRATEGY_ADDRESS'
        );

        require(
            strategy.vat() == expectedStrategyValues.vat,
            '_validateDaiInterestRateStrategy() : INVALID_VAT'
        );
        require(
            strategy.pot() == expectedStrategyValues.pot,
            '_validateDaiInterestRateStrategy() : INVALID_POT'
        );
        require(
            strategy.ilk() == expectedStrategyValues.ilk,
            '_validateDaiInterestRateStrategy() : INVALID_ILK'
        );
        require(
            strategy.baseRateConversion() == expectedStrategyValues.baseRateConversion,
            '_validateDaiInterestRateStrategy() : INVALID_BASE_RATE_CONVERSION'
        );
        require(
            strategy.borrowSpread() == expectedStrategyValues.borrowSpread,
            '_validateDaiInterestRateStrategy() : INVALID_BORROW_SPREAD'
        );
        require(
            strategy.supplySpread() == expectedStrategyValues.supplySpread,
            '_validateDaiInterestRateStrategy() : INVALID_SUPPLY_SPREAD'
        );
        require(
            strategy.maxRate() == expectedStrategyValues.maxRate,
            '_validateDaiInterestRateStrategy() : INVALID_MAX_RATE'
        );
        require(
            strategy.performanceBonus() == expectedStrategyValues.performanceBonus,
            '_validateDaiInterestRateStrategy() : INVALID_PERFORMANCE_BONUS'
        );
    }

    function _validateDaiJugInterestRateStrategy(
        address interestRateStrategyAddress,
        address expectedStrategy,
        DaiJugInterestStrategyValues memory expectedStrategyValues
    ) internal view {
        IDaiJugInterestRateStrategy strategy = IDaiJugInterestRateStrategy(
            interestRateStrategyAddress
        );

        require(
            address(strategy) == expectedStrategy,
            '_validateDaiInterestRateStrategy() : INVALID_STRATEGY_ADDRESS'
        );

        require(
            strategy.vat() == expectedStrategyValues.vat,
            '_validateDaiInterestRateStrategy() : INVALID_VAT'
        );
        require(
            strategy.jug() == expectedStrategyValues.jug,
            '_validateDaiInterestRateStrategy() : INVALID_JUG'
        );
        require(
            strategy.ilk() == expectedStrategyValues.ilk,
            '_validateDaiInterestRateStrategy() : INVALID_ILK'
        );
        require(
            strategy.baseRateConversion() == expectedStrategyValues.baseRateConversion,
            '_validateDaiInterestRateStrategy() : INVALID_BASE_RATE_CONVERSION'
        );
        require(
            strategy.borrowSpread() == expectedStrategyValues.borrowSpread,
            '_validateDaiInterestRateStrategy() : INVALID_BORROW_SPREAD'
        );
        require(
            strategy.supplySpread() == expectedStrategyValues.supplySpread,
            '_validateDaiInterestRateStrategy() : INVALID_SUPPLY_SPREAD'
        );
        require(
            strategy.maxRate() == expectedStrategyValues.maxRate,
            '_validateDaiInterestRateStrategy() : INVALID_MAX_RATE'
        );
        require(
            strategy.performanceBonus() == expectedStrategyValues.performanceBonus,
            '_validateDaiInterestRateStrategy() : INVALID_PERFORMANCE_BONUS'
        );
    }

}

abstract contract SparkEthereumTestBase is SparkTestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    IAuthority           internal authority;
    ISparkLendFreezerMom internal freezerMom;

    address INCENTIVES_CONTROLLER = 0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;

    address DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address MKR  = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;

    address SPELL_FREEZE_ALL = 0xA67d62f75F8D11395eE120CA8390Ab3bF01f0b8A;
    address SPELL_FREEZE_DAI = 0x0F9149c4d6018A5999AdA5b592E372845cfeC725;
    address SPELL_PAUSE_ALL  = 0x216738c7B1E83cC1A1FFcD3433226B0a3B174484;
    address SPELL_PAUSE_DAI  = 0x1B94E2F3818E1D657bE2A62D37560514b52DB17F;

    constructor() {
        executor          = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
        domain            = 'Ethereum';
        disableExportDiff = true;  // Remove this to generate the diff report

        poolAddressesProviderRegistry = IPoolAddressesProviderRegistry(0x03cFa0C4622FF84E50E75062683F44c9587e6Cc1);
        authority                     = IAuthority(0x0a3f6849f78076aefaDf113F5BED87720274dDC0);
        freezerMom                    = ISparkLendFreezerMom(0xFA36c12Bc307b40c701D65d8FE8F88cCEdE2277a);
    }

    function testFreezerMom() public {
        uint256 snapshot = vm.snapshot();

        _runFreezerMomTests();

        vm.revertTo(snapshot);
        GovHelpers.executePayload(vm, payload, executor);

        _runFreezerMomTests();
    }

    function testRewardsConfiguration() public {
        _runRewardsConfigurationTests();

        GovHelpers.executePayload(vm, payload, executor);

        _runRewardsConfigurationTests();
    }

    function _runRewardsConfigurationTests() internal {
        address[] memory reserves = pool.getReservesList();

        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(reserves[i]);

            assertEq(address(IncentivizedERC20(reserveData.aTokenAddress).getIncentivesController()),            INCENTIVES_CONTROLLER);
            assertEq(address(IncentivizedERC20(reserveData.variableDebtTokenAddress).getIncentivesController()), INCENTIVES_CONTROLLER);
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

        deal(MKR, mkrWhale, amount);

        vm.startPrank(mkrWhale);
        IERC20(MKR).approve(address(authority), amount);
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
        freezerMom.freezeMarket(DAI, true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.freezeAllMarkets(true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.pauseMarket(DAI, true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.pauseAllMarkets(true);

        _assertFrozen(DAI,  false);
        _assertFrozen(WETH, false);
        _voteAndCast(SPELL_FREEZE_DAI);
        _assertFrozen(DAI,  true);
        _assertFrozen(WETH, false);

        _voteAndCast(SPELL_FREEZE_ALL);
        _assertFrozen(DAI,  true);
        _assertFrozen(WETH, true);

        _assertPaused(DAI,  false);
        _assertPaused(WETH, false);
        _voteAndCast(SPELL_PAUSE_DAI);
        _assertPaused(DAI,  true);
        _assertPaused(WETH, false);

        _voteAndCast(SPELL_PAUSE_ALL);
        _assertPaused(DAI,  true);
        _assertPaused(WETH, true);
    }

}

abstract contract SparkGoerliTestBase is SparkTestBase {

    constructor() {
        executor = 0x4e847915D8a9f2Ab0cDf2FC2FD0A30428F25665d;
        domain   = 'Goerli';

        poolAddressesProviderRegistry = IPoolAddressesProviderRegistry(0x1ad570fDEA255a3c1d8Cf56ec76ebA2b7bFDFfea);
    }

}

abstract contract SparkGnosisTestBase is SparkTestBase {

    constructor() {
        executor = 0xc4218C1127cB24a0D6c1e7D25dc34e10f2625f5A;
        domain   = 'Gnosis';

        poolAddressesProviderRegistry = IPoolAddressesProviderRegistry(0x49d24798d3b84965F0d1fc8684EF6565115e70c1);
    }

}
