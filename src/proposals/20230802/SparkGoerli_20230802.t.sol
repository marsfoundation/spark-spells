// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { console2 as console } from "../../../lib/forge-std/src/console2.sol";

import { IPool }                from "aave-v3-core/contracts/interfaces/IPool.sol";
import { ReserveConfiguration } from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

import { ReserveConfig }    from 'aave-helpers/ProtocolV3TestBase.sol';
import { TestWithExecutor } from 'aave-helpers/GovHelpers.sol';

import { InterestStrategyValues, SparkTestBase } from '../../SparkTestBase.sol';

import { IDaiInterestRateStrategy } from '../../IDaiInterestRateStrategy.sol';

import { SparkGoerli_20230802 } from './SparkGoerli_20230802.sol';

interface IPotLike {
	function drip() external returns (uint256);
	function dsr() external view returns (uint256);
	function file(bytes32, uint256) external;
}

contract SparkGoerli_20230802Test is SparkTestBase, TestWithExecutor {

	using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

	address public constant DAI    = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
	address public constant WETH   = 0x7D5afF7ab67b431cDFA6A94d50d3124cC4AB2611;

	address public constant POOL_ADDRESSES_PROVIDER = 0x026a5B6114431d8F3eF2fA0E1B2EDdDccA9c540E;

	address public constant DAI_INTEREST_RATE_STRATEGY_OLD
		= 0x70659BcA22A2a8BB324A526a8BB919185d3ecEBC;

	address public constant DAI_INTEREST_RATE_STRATEGY_NEW
		= 0x7f44e1c1dE70059D7cc483378BEFeE2a030CE247;

	address public constant PAUSE_PROXY = 0x5DCdbD3cCF9B09EAAD03bc5f50fA2B3d3ACA0121;

    address public constant MCD_VAT = 0xB966002DDAa2Baf48369f5015329750019736031;
    address public constant MCD_JUG = 0xC90C99FE9B5d5207A03b9F28A6E8A19C0e558916;
	address public constant MCD_POT = 0x50672F0a14B40051B65958818a7AcA3D54Bd81Af;

	address public constant EXECUTOR = 0x4e847915D8a9f2Ab0cDf2FC2FD0A30428F25665d;

	bytes32 public constant SPARK_ILK = "DIRECT-SPARK-DAI";

	uint256 internal constant RAY = 1e27;

	IPool public constant POOL = IPool(0x26ca51Af4506DE7a6f0785D20CD776081a05fF6d);

	DataTypes.CalculateInterestRatesParams public rateParams =
		DataTypes.CalculateInterestRatesParams(
			0,
			0,
			0,
			0,
			1_000_000_000e18,
			0,
			0,
			DAI,
			address(0)
		);

	SparkGoerli_20230802 public payload;

	function setUp() public {
		vm.createSelectFork(getChain('goerli').rpcUrl, 9_343_000);

		_selectPayloadExecutor(EXECUTOR);

		payload = new SparkGoerli_20230802();
	}

	function testSpellExecution() public {
		IDaiInterestRateStrategy daiStrategy = IDaiInterestRateStrategy(
			DAI_INTEREST_RATE_STRATEGY_OLD
		);

		ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot(
			'pre-Spark-Goerli-20230802',
			POOL
		);

		/********************************************/
		/*** Dai Strategy Before State Assertions ***/
		/********************************************/

		console.log("Strat", _findReserveConfigBySymbol(allConfigsBefore, 'DAI').interestRateStrategy);
		console.log("Strat", DAI_INTEREST_RATE_STRATEGY_OLD);

		_validateDaiInterestRateStrategy(
            _findReserveConfigBySymbol(allConfigsBefore, 'DAI').interestRateStrategy,
            DAI_INTEREST_RATE_STRATEGY_OLD,
            DaiInterestStrategyValues({
                vat:                MCD_VAT,
                pot:                MCD_POT,
                ilk:                SPARK_ILK,
                baseRateConversion: RAY,
                borrowSpread:       0,
                supplySpread:       0,
                maxRate:            0.75e27,
                performanceBonus:   0
            })
        );

		daiStrategy.recompute();

		uint256 startingDsr           = IPotLike(MCD_POT).dsr();
		uint256 startingAnnualizedDsr = _getAnnualizedDsr(startingDsr);

		// ETH-C rate at ~3.14% (currently equals annualized DSR)
		uint256 stabilityFee = 0.031401763155165655148976000e27;

		( ,, uint256 borrowRate ) = daiStrategy.calculateInterestRates(rateParams);

		assertEq(startingDsr,               1.000000000995743377573746041e27);
		assertEq(daiStrategy.getBaseRate(), stabilityFee);
		assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);
		assertEq(borrowRate,                startingAnnualizedDsr);

		uint256 updatedDsr = 1.000000001585489599188229325e27;  // ~5% annualized

		IPotLike(MCD_POT).drip();
		vm.prank(PAUSE_PROXY);
		IPotLike(MCD_POT).file('dsr', updatedDsr);

		daiStrategy.recompute();

		uint256 updatedAnnualizedDsr = _getAnnualizedDsr(updatedDsr);

		( ,, borrowRate ) = daiStrategy.calculateInterestRates(rateParams);

		// Demonstrate that old strategy is directly affected by DSR change
		assertEq(IPotLike(MCD_POT).dsr(),   updatedDsr);
		assertEq(daiStrategy.getBaseRate(), 0.049999999999999999993200000e27);  // ~5%
		assertEq(daiStrategy.getBaseRate(), updatedAnnualizedDsr);
		assertEq(borrowRate,                updatedAnnualizedDsr);


		// Go back to starting state before execution
		IPotLike(MCD_POT).drip();
		vm.prank(PAUSE_PROXY);
		IPotLike(MCD_POT).file('dsr', startingDsr);

		daiStrategy.recompute();

		( ,, borrowRate ) = daiStrategy.calculateInterestRates(rateParams);

		assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);  // Back to 3.43%
		assertEq(borrowRate,                startingAnnualizedDsr);

		/*****************/
		/*** Execution ***/
		/*****************/

		_executePayload(address(payload));

		ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot(
			'post-Spark-Goerli-20230802',
			POOL
		);

		_validateDaiJugInterestRateStrategy(
            _findReserveConfigBySymbol(allConfigsAfter, 'DAI').interestRateStrategy,
            DAI_INTEREST_RATE_STRATEGY_NEW,
            DaiJugInterestStrategyValues({
                vat:                MCD_VAT,
                jug:                MCD_JUG,
                ilk:                SPARK_ILK,
                baseRateConversion: RAY,
                borrowSpread:       0,
                supplySpread:       0,
                maxRate:            0.75e27,
                performanceBonus:   0
            })
        );

		daiStrategy = IDaiInterestRateStrategy(DAI_INTEREST_RATE_STRATEGY_NEW);

		daiStrategy.recompute();

		( ,, borrowRate ) = daiStrategy.calculateInterestRates(rateParams);

		// Starting state is in line with DSR since ETH-C SFBR matches DSR
		assertEq(IPotLike(MCD_POT).dsr(),   startingDsr);
		assertEq(daiStrategy.getBaseRate(), stabilityFee);
		assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);
		assertEq(borrowRate,                stabilityFee);

		// Change DSR to ~5% annualized
		IPotLike(MCD_POT).drip();
		vm.prank(PAUSE_PROXY);
		IPotLike(MCD_POT).file('dsr', updatedDsr);

		daiStrategy.recompute();

		// Demonstrate that new strategy is NOT affected by DSR change
		assertEq(IPotLike(MCD_POT).dsr(),   updatedDsr);             // DSR is 5% annualized
		assertEq(daiStrategy.getBaseRate(), stabilityFee);           // Still 3.43%
		assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);  // Still 3.43%
		assertEq(borrowRate,                stabilityFee);           // Still 3.43%

		/***************************************/
		/*** DAI Collateral State Assertions ***/
		/***************************************/

		ReserveConfig memory DAI_EXPECTED_CONFIG = _findReserveConfig(allConfigsAfter, DAI);

		DAI_EXPECTED_CONFIG.liquidationThreshold = 1;
		DAI_EXPECTED_CONFIG.ltv                  = 1;

		// DAI is still technically enabled as collateral, just with a 0.01% liquidation threshold
		// This is because DAI is being supplied by Maker, and AAVE prevents liquidation threshold
		// being set to zero with active suppliers.
		DAI_EXPECTED_CONFIG.usageAsCollateralEnabled = true;

		_validateReserveConfig(DAI_EXPECTED_CONFIG, allConfigsAfter);

		/****************************************/
		/*** WETH Collateral State Assertions ***/
		/****************************************/

		ReserveConfig memory WETH_EXPECTED_CONFIG = _findReserveConfig(allConfigsAfter, WETH);

		WETH_EXPECTED_CONFIG.reserveFactor = 5_00;

		_validateReserveConfig(WETH_EXPECTED_CONFIG, allConfigsAfter);

		_validateInterestRateStrategy(
			WETH_EXPECTED_CONFIG.interestRateStrategy,
			WETH_EXPECTED_CONFIG.interestRateStrategy,
			InterestStrategyValues({
				addressesProvider:             POOL_ADDRESSES_PROVIDER,
				optimalUsageRatio:             0.80e27,
				optimalStableToTotalDebtRatio: 0,
				baseStableBorrowRate:          0.0375e27,
				stableRateSlope1:              0,
				stableRateSlope2:              0,
				baseVariableBorrowRate:        0.01e27,
				variableRateSlope1:            0.0375e27,
				variableRateSlope2:            0.80e27
			})
		);

		/*****************/
		/*** E2E Tests ***/
		/*****************/

		sparkE2eTest(POOL, makeAddr("newUser"));
	}

	function _getAnnualizedDsr(uint256 dsr) internal pure returns (uint256) {
		return (dsr - RAY) * 365 days;
	}
}
