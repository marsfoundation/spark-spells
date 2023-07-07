// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IPool }                from "aave-v3-core/contracts/interfaces/IPool.sol";
import { ReserveConfiguration } from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import { DataTypes }            from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

import { TestWithExecutor } from 'aave-helpers/GovHelpers.sol';

import { SparkTestBase  } from '../../SparkTestBase.sol';

import { SparkEthereum_20230802 } from './SparkEthereum_20230802.sol';

contract SparkEthereum_20230802Test is SparkTestBase, TestWithExecutor {

  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  IPool internal constant POOL = IPool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);

  SparkEthereum_20230802 public payload;

  function setUp() public {
    vm.createSelectFork(getChain('mainnet').rpcUrl, 17_642_000);
    payload = new SparkEthereum_20230802();
  }

  function test_proposalExecution() public {
    createConfigurationSnapshot(
      'pre-Spark-Ethereum-EMode-20230802',
      POOL
  );

    // GovHelpers.executePayload(vm, address(payload), AaveGovernanceV2.OPTIMISM_BRIDGE_EXECUTOR);

    // ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot(
    //   'post-Aave-V3-Optimism-EMode-20220622',
    //   AaveV3Optimism.POOL
    // );

    // ReserveConfig memory weth = _findReserveConfig(
    //   allConfigsBefore,
    //   AaveV3OptimismAssets.WETH_UNDERLYING
    // );
    // ReserveConfig memory wsteth = _findReserveConfig(
    //   allConfigsBefore,
    //   AaveV3OptimismAssets.wstETH_UNDERLYING
    // );

    // weth.eModeCategory = payload.EMODE_CATEGORY_ID_ETH_CORRELATED();
    // wsteth.eModeCategory = payload.EMODE_CATEGORY_ID_ETH_CORRELATED();

    // _validateReserveConfig(weth, allConfigsAfter);
    // _validateReserveConfig(wsteth, allConfigsAfter);

    // diffReports('pre-Aave-V3-Optimism-EMode-20220622', 'post-Aave-V3-Optimism-EMode-20220622');
  }
}
