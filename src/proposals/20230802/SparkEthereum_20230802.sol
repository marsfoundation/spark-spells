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

    string public constant EMODE_LABEL_WETH   = 'sDAI allowed - WETH';
    string public constant EMODE_LABEL_WSTETH = 'sDAI allowed - wstETH';

    uint16 public constant EMODE_LTV_WETH   = 80_01;
    uint16 public constant EMODE_LTV_WSTETH = 68_51;

    uint16 public constant EMODE_LT_WSTETH = 79_51;
    uint16 public constant EMODE_LT_WETH   = 82_51;

    uint16 public constant EMODE_LBONUS_WETH   = 105_00;  // 5%
    uint16 public constant EMODE_LBONUS_WSTETH = 107_00;  // 7%

    uint8 public constant EMODE_CATEGORY_ID_WETH   = 2;
    uint8 public constant EMODE_CATEGORY_ID_WSTETH = 3;

    address public constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address public constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function _postExecute() internal override {
		LISTING_ENGINE.POOL_CONFIGURATOR().setEModeCategory(
			EMODE_CATEGORY_ID_WETH,
			EMODE_LTV_WETH,
			EMODE_LT_WETH,
			EMODE_LBONUS_WETH,
			address(0),
			EMODE_LABEL_WETH
		);

		LISTING_ENGINE.POOL_CONFIGURATOR().setEModeCategory(
			EMODE_CATEGORY_ID_WSTETH,
			EMODE_LTV_WSTETH,
			EMODE_LT_WSTETH,
			EMODE_LBONUS_WSTETH,
			address(0),
			EMODE_LABEL_WSTETH
		);

		LISTING_ENGINE.POOL_CONFIGURATOR().setAssetEModeCategory(SDAI,   EMODE_CATEGORY_ID_WETH);
		LISTING_ENGINE.POOL_CONFIGURATOR().setAssetEModeCategory(WETH,   EMODE_CATEGORY_ID_WETH);
		LISTING_ENGINE.POOL_CONFIGURATOR().setAssetEModeCategory(WSTETH, EMODE_CATEGORY_ID_WSTETH);
    }

}
