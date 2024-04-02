// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IACLManager } from 'lib/aave-v3-core/contracts/interfaces/IACLManager.sol';


import { ICapAutomator }             from 'src/interfaces/ICapAutomator.sol';
import { IKillSwitchOracle }         from 'src/interfaces/IKillSwitchOracle.sol';
import { IMetaMorpho, MarketParams } from 'src/interfaces/IMetaMorpho.sol';

import { SparkPayloadEthereum } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  April 3, 2024 Spark Ethereum Proposal
 * @notice Activate Killswitch with wstETH and WBTC, WBTC Max Supply Cap to 10k, ETH Borrow Gap to 20k, Morpho Vault Supply Cap Adjustments.
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/mar-21-2024-proposed-changes-to-sparklend-for-upcoming-spell/23918
 *         https://forum.makerdao.com/t/morpho-spark-dai-vault-update-1-april-2024/24006
 * Votes:  https://vote.makerdao.com/polling/QmdjqTvL
 *         https://vote.makerdao.com/polling/QmbCWUAP
 *         https://vote.makerdao.com/polling/QmaEqEav
 */
contract SparkEthereum_20240403 is SparkPayloadEthereum {

    address internal constant DAI   = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WBTC  = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant USDE  = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

    address internal constant WBTC_BTC_ORACLE  = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;
    address internal constant STETH_ETH_ORACLE = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;

    address internal constant ACL_MANAGER        = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address internal constant CAP_AUTOMATOR      = 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef;
    address internal constant KILL_SWITCH_ORACLE = 0x909A86f78e1cdEd68F9c2Fe2c9CD922c401abe82;
    address internal constant MORPHO_VAULT       = 0x73e65DBD630f90604062f6E02fAb9138e713edD9;

    address internal constant SUSDE_ORACLE = 0x5D916980D5Ae1737a8330Bf24dF812b2911Aae25;
    address internal constant USDE_ORACLE  = 0xaE4750d0813B5E37A51f7629beedd72AF1f9cA35;

    address internal constant MORPHO_DEFAULT_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

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

        // Adjust Morpho Vault supply caps
        IMetaMorpho(MORPHO_VAULT).submitCap(MarketParams({
            loanToken:       DAI,
            collateralToken: SUSDE,
            oracle:          SUSDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        }), 200_000_000 ether);
        IMetaMorpho(MORPHO_VAULT).submitCap(MarketParams({
            loanToken:       DAI,
            collateralToken: USDE,
            oracle:          USDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        }), 500_000_000 ether);
        IMetaMorpho(MORPHO_VAULT).submitCap(MarketParams({
            loanToken:       DAI,
            collateralToken: USDE,
            oracle:          USDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        }), 200_000_000 ether);
    }

}
