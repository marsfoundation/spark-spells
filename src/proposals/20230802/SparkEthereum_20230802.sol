// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title List rETH on Spark Ethereum
 * @author Phoenix Labs
 * @dev This proposal lists rETH + updates DAI interest rate strategy on Spark Ethereum
 * Forum:        https://forum.makerdao.com/t/2023-05-24-spark-protocol-updates/20958
 * rETH Vote:    https://vote.makerdao.com/polling/QmeEV7ph#poll-detail
 * DAI IRS Vote: https://vote.makerdao.com/polling/QmWodV1J#poll-detail
 */
contract SparkEthereum_20230802 is SparkPayloadEthereum {

    address public constant DAI                        = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant DAI_INTEREST_RATE_STRATEGY = 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;

    string public constant EMODE_LABEL       = 'sDAI allowed';
    uint16 public constant EMODE_LTV         = 68_50;
    uint16 public constant EMODE_LT          = 79_50;
    uint16 public constant EMODE_LBONUS      = 7_00;
    uint8  public constant EMODE_CATEGORY_ID = 2;

  // function execute() external {
  //   LISTING_ENGINE.POOL_CONFIGURATOR().setEModeCategory(
  //       EMODE_CATEGORY_ID,
  //       EMODE_LTV,
  //       EMODE_LT,
  //       EMODE_LBONUS,
  //       address(0),
  //       EMODE_LABEL
  //   );

  //   // LISTING_ENGINE.POOL_CONFIGURATOR().setAssetEModeCategory(
  //   //   LISTING_ENGINE.WETH_UNDERLYING,
  //   //   EMODE_CATEGORY_ID_ETH_CORRELATED
  //   // );

  //   // AaveV3Optimism.POOL_CONFIGURATOR().setAssetEModeCategory(
  //   //   AaveV3OptimismAssets.wstETH_UNDERLYING,
  //   //   EMODE_CATEGORY_ID_ETH_CORRELATED
  //   // );
  // }

    function _postExecute() internal override {
      LISTING_ENGINE.POOL_CONFIGURATOR().setEModeCategory(
        EMODE_CATEGORY_ID,
        EMODE_LTV,
        EMODE_LT,
        EMODE_LBONUS,
        address(0),
        EMODE_LABEL
    );

        // // Update the DAI interest rate strategy
        // LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
        //     DAI,
        //     DAI_INTEREST_RATE_STRATEGY
        // );
    }

}
