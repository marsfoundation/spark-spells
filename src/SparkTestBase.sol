// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'aave-helpers/ProtocolV3TestBase.sol';

import { GovHelpers } from 'aave-helpers/GovHelpers.sol';

import { IPool }                          from 'aave-v3-core/contracts/interfaces/IPool.sol';
import { IPoolAddressesProvider }         from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';
import { IPoolAddressesProviderRegistry } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProviderRegistry.sol';

import { IDaiInterestRateStrategy }    from "./IDaiInterestRateStrategy.sol";
import { IDaiJugInterestRateStrategy } from "./IDaiJugInterestRateStrategy.sol";

abstract contract SparkTestBase is ProtocolV3TestBase {

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

    IPoolAddressesProviderRegistry internal poolAddressesProviderRegistry;
    IPoolAddressesProvider         internal poolAddressesProvider;
    IPool                          internal pool;

    function loadPoolContext(address poolProvider) internal {
        poolAddressesProvider = IPoolAddressesProvider(poolProvider);
        pool                  = IPool(poolAddressesProvider.getPool());
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

            // Goerli is broken so just disable for now
            if (block.chainid != 5) {
                diffReportsFixed(
                    string(abi.encodePacked(prefix, '-', vm.toString(address(pool)), '-pre')),
                    string(abi.encodePacked(prefix, '-', vm.toString(address(pool)), '-post'))
                );
            }
        }
    }

    function testE2E() public {
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

    function _liquidate(
        ReserveConfig memory collateral,
        ReserveConfig memory debt,
        address liquidator,
        address user,
        uint256 amount
    ) internal {
        vm.startPrank(liquidator);
        deal(debt.underlying, liquidator, amount);
        IERC20(debt.underlying).approve(address(pool), amount);
        console.log('LIQUIDATION_CALL: Collateral: %s, Debt: %s, Amount: %s', collateral.symbol, debt.symbol, amount);
        pool.liquidationCall(collateral.underlying, debt.underlying, user, amount, false);
        vm.stopPrank();
    }

    function diffReportsFixed(string memory reportBefore, string memory reportAfter) internal {
        string memory outPath = string(
            abi.encodePacked('./diffs/', reportBefore, '_', reportAfter, '.md')
        );
        string memory beforePath = string(abi.encodePacked('./reports/', reportBefore, '.json'));
        string memory afterPath  = string(abi.encodePacked('./reports/', reportAfter,  '.json'));

        string[] memory inputs = new string[](7);
        inputs[0] = 'npx';
        inputs[1] = '@bgd-labs/aave-cli';   // This reference is broken in the original code
        inputs[2] = 'diff-snapshots';
        inputs[3] = beforePath;
        inputs[4] = afterPath;
        inputs[5] = '-o';
        inputs[6] = outPath;
        vm.ffi(inputs);
    }

}

abstract contract SparkEthereumTestBase is SparkTestBase {

    constructor() {
        executor = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
        domain = 'Ethereum';
        poolAddressesProviderRegistry = IPoolAddressesProviderRegistry(0x03cFa0C4622FF84E50E75062683F44c9587e6Cc1);
    }

}

abstract contract SparkGoerliTestBase is SparkTestBase {

    constructor() {
        executor = 0x4e847915D8a9f2Ab0cDf2FC2FD0A30428F25665d;
        domain = 'Goerli';
        poolAddressesProviderRegistry = IPoolAddressesProviderRegistry(0x1ad570fDEA255a3c1d8Cf56ec76ebA2b7bFDFfea);
    }

}
