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

import { SparkEthereum_20230802 } from './SparkEthereum_20230802.sol';

interface IPotLike {
	function drip() external returns (uint256);
	function dsr() external view returns (uint256);
	function file(bytes32, uint256) external;
}

contract SparkEthereum_20230802Test is SparkTestBase, TestWithExecutor {

	using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

	address public constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
	address public constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
	address public constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

	address public constant POOL_ADDRESSES_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;

	address public constant DAI_INTEREST_RATE_STRATEGY_OLD
		= 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;

	address public constant DAI_INTEREST_RATE_STRATEGY_NEW
		= 0x191E97623B1733369290ee5d018d0B068bc0400D;

	address public constant PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    address public constant MCD_VAT = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address public constant MCD_JUG = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;
	address public constant MCD_POT = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;

	address public constant EXECUTOR = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

	bytes32 public constant SPARK_ILK = "DIRECT-SPARK-DAI";

	uint256 internal constant RAY  = 1e27;

	IPool public constant POOL = IPool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);

	SparkEthereum_20230802 public payload;

	function setUp() public {
		vm.createSelectFork(getChain('mainnet').rpcUrl, 17_677_900);

		_selectPayloadExecutor(EXECUTOR);

		payload = new SparkEthereum_20230802();
	}

	function test_proposalExecution() public {
		IDaiInterestRateStrategy daiStrategy = IDaiInterestRateStrategy(
			DAI_INTEREST_RATE_STRATEGY_OLD
		);

		ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot(
			'pre-Spark-Ethereum-20230802',
			POOL
		);

		/********************************************/
		/*** Dai Strategy Before State Assertions ***/
		/********************************************/

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
                maxRate:            75 * (RAY / 100),
                performanceBonus:   0
            })
        );

		daiStrategy.recompute();

		uint256 startingDsr           = IPotLike(MCD_POT).dsr();
		uint256 startingAnnualizedDsr = _getAnnualizedDsr(startingDsr);

		// ETH-C rate at 3.43% (currently equals annualized DSR)
		uint256 stabilityFee  = 0.034304803710648653896272000e27;

		assertEq(startingDsr,               1.000000001087798189708544327e27);
		assertEq(daiStrategy.getBaseRate(), stabilityFee);
		assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);

		uint256 updatedDsr = 1.000000001585489599188229325e27;  // ~5% annualized

		IPotLike(MCD_POT).drip();
		vm.prank(PAUSE_PROXY);
		IPotLike(MCD_POT).file('dsr', updatedDsr);

		daiStrategy.recompute();

		uint256 updatedAnnualizedDsr = _getAnnualizedDsr(updatedDsr);

		// Demonstrate that old strategy is directly affected by DSR change
		assertEq(IPotLike(MCD_POT).dsr(),   updatedDsr);
		assertEq(daiStrategy.getBaseRate(), 0.049999999999999999993200000e27);  // ~5%
		assertEq(daiStrategy.getBaseRate(), updatedAnnualizedDsr);

		// Go back to starting state before execution
		IPotLike(MCD_POT).drip();
		vm.prank(PAUSE_PROXY);
		IPotLike(MCD_POT).file('dsr', startingDsr);

		daiStrategy.recompute();

		assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);  // Back to 3.43%

		/*****************/
		/*** Execution ***/
		/*****************/

		_executePayload(address(payload));

		ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot(
			'post-Spark-Ethereum-20230802',
			POOL
		);

		diffReports(
			'pre-Spark-Ethereum-20230802',
			'post-Spark-Ethereum-20230802'
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
                maxRate:            75 * (RAY / 100),
                performanceBonus:   0
            })
        );

		daiStrategy = IDaiInterestRateStrategy(DAI_INTEREST_RATE_STRATEGY_NEW);

		daiStrategy.recompute();

		// Starting state is in line with DSR since ETH-C SFBR matches DSR
		assertEq(IPotLike(MCD_POT).dsr(),   startingDsr);
		assertEq(daiStrategy.getBaseRate(), stabilityFee);
		assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);

		// Change DSR to ~5% annualized
		IPotLike(MCD_POT).drip();
		vm.prank(PAUSE_PROXY);
		IPotLike(MCD_POT).file('dsr', updatedDsr);

		daiStrategy.recompute();

		// Demonstrate that new strategy is NOT affected by DSR change
		assertEq(IPotLike(MCD_POT).dsr(),   updatedDsr);             // DSR is 5% annualized
		assertEq(daiStrategy.getBaseRate(), stabilityFee);           // Still 3.43%
		assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);  // Still 3.43%

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
				baseStableBorrowRate:          0.04e27,  // Only value changing
				stableRateSlope1:              0,
				stableRateSlope2:              0,
				baseVariableBorrowRate:        0.01e27,
				variableRateSlope1:            0.04e27,
				variableRateSlope2:            0.80e27
			})
		);

		/**********************************/
		/*** E2E Tests for WETH and DAI ***/
		/**********************************/

		sparkE2eTest(POOL, makeAddr("newUser"));
	}

	function _getAnnualizedDsr(uint256 dsr) internal pure returns (uint256) {
		return (dsr - RAY) * 365 days;
	}
}
