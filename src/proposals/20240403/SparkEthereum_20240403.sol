// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IACLManager } from 'aave-v3-core/contracts/interfaces/IACLManager.sol';

import { ICapAutomator }     from 'src/interfaces/ICapAutomator.sol';
import { IKillSwitchOracle } from 'src/interfaces/IKillSwitchOracle.sol';

import { SparkPayloadEthereum } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  April 3, 2024 Spark Ethereum Proposal - Activate Killswitch with wstETH and WBTC, WBTC Max Supply Cap to 10k, ETH Borrow Gap to 20k
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/mar-21-2024-proposed-changes-to-sparklend-for-upcoming-spell/23918
 * Votes:  https://vote.makerdao.com/polling/QmdjqTvL
 *         https://vote.makerdao.com/polling/QmbCWUAP
 *         https://vote.makerdao.com/polling/QmaEqEav
 */
contract SparkEthereum_20240403 is SparkPayloadEthereum {

    address internal constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WBTC   = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address internal constant WBTC_BTC_ORACLE  = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;
    address internal constant STETH_ETH_ORACLE = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;

    address internal constant ACL_MANAGER        = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address internal constant CAP_AUTOMATOR      = 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef;
    address internal constant KILL_SWITCH_ORACLE = 0x909A86f78e1cdEd68F9c2Fe2c9CD922c401abe82;

    function _postExecute()
        internal override
    {
        // Kill switch activation
        // Be sure to check decimals for the threshold values
        IACLManager(ACL_MANAGER).addRiskAdmin(KILL_SWITCH_ORACLE);
        IKillSwitchOracle(KILL_SWITCH_ORACLE).setOracle(WBTC_BTC_ORACLE,  0.95e8);
        IKillSwitchOracle(KILL_SWITCH_ORACLE).setOracle(STETH_ETH_ORACLE, 0.95e18);

        // Cap automator updates
        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: WBTC, max: 10_000,    gap: 500,    increaseCooldown: 12 hours});
        ICapAutomator(CAP_AUTOMATOR).setBorrowCapConfig({asset: WETH, max: 1_000_000, gap: 20_000, increaseCooldown: 12 hours});
    }

}
