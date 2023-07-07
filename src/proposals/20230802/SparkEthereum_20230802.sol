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

    string public constant EMODE_LABEL       = 'sDAI allowed';
    uint16 public constant EMODE_LTV         = 68_50;
    uint16 public constant EMODE_LT          = 83_00;   // 79_50
    uint16 public constant EMODE_LBONUS      = 107_00;  // 7%
    uint8  public constant EMODE_CATEGORY_ID = 2;

    address public constant RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address public constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address public constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function _postExecute() internal override {
      LISTING_ENGINE.POOL_CONFIGURATOR().setEModeCategory(
          EMODE_CATEGORY_ID,
          EMODE_LTV,
          EMODE_LT,
          EMODE_LBONUS,
          address(0),
          EMODE_LABEL
      );

      LISTING_ENGINE.POOL_CONFIGURATOR().setAssetEModeCategory(RETH,   EMODE_CATEGORY_ID);
      LISTING_ENGINE.POOL_CONFIGURATOR().setAssetEModeCategory(SDAI,   EMODE_CATEGORY_ID);
      LISTING_ENGINE.POOL_CONFIGURATOR().setAssetEModeCategory(WETH,   EMODE_CATEGORY_ID);
      LISTING_ENGINE.POOL_CONFIGURATOR().setAssetEModeCategory(WSTETH, EMODE_CATEGORY_ID);
    }

}
