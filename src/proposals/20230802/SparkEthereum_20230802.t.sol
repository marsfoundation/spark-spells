// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IPool }                from "aave-v3-core/contracts/interfaces/IPool.sol";
import { ReserveConfiguration } from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

import { ReserveConfig }    from 'aave-helpers/ProtocolV3TestBase.sol';
import { TestWithExecutor } from 'aave-helpers/GovHelpers.sol';

import { SparkTestBase } from '../../SparkTestBase.sol';

import { SparkEthereum_20230802 } from './SparkEthereum_20230802.sol';

contract SparkEthereum_20230802Test is SparkTestBase, TestWithExecutor {

	using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

	address public constant RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;
	address public constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
	address public constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

	address internal constant EXECUTOR = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

	IPool internal constant POOL = IPool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);

	SparkEthereum_20230802 public payload;

	function setUp() public {
		vm.createSelectFork(getChain('mainnet').rpcUrl, 17_642_000);

		_selectPayloadExecutor(EXECUTOR);

		payload = new SparkEthereum_20230802();
	}

	function test_proposalExecution() public {
		ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot(
			'pre-Spark-Ethereum-EMode-20230802',
			POOL
		);

		_executePayload(address(payload));

		ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot(
			'post-Spark-Ethereum-EMode-20230802',
			POOL
		);

		diffReports(
			'pre-Spark-Ethereum-EMode-20230802',
			'post-Spark-Ethereum-EMode-20230802'
		);

		ReserveConfig memory reth   = _findReserveConfig(allConfigsBefore, RETH);
		ReserveConfig memory sdai   = _findReserveConfig(allConfigsBefore, SDAI);
		ReserveConfig memory weth   = _findReserveConfig(allConfigsBefore, WETH);
		ReserveConfig memory wsteth = _findReserveConfig(allConfigsBefore, WSTETH);

		reth.eModeCategory   = payload.EMODE_CATEGORY_ID();
		sdai.eModeCategory   = payload.EMODE_CATEGORY_ID();
		weth.eModeCategory   = payload.EMODE_CATEGORY_ID();
		wsteth.eModeCategory = payload.EMODE_CATEGORY_ID();

		_validateReserveConfig(reth,   allConfigsAfter);
		_validateReserveConfig(sdai,   allConfigsAfter);
		_validateReserveConfig(weth,   allConfigsAfter);
		_validateReserveConfig(wsteth, allConfigsAfter);

		// diffReports('pre-Aave-V3-Optimism-EMode-20220622', 'post-Aave-V3-Optimism-EMode-20220622');
	}
}
