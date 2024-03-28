// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { ICapAutomator } from '../../interfaces/ICapAutomator.sol';

import { SparkPayloadEthereum } from '../../SparkPayloadEthereum.sol';

interface IOwnable {
    function acceptOwnership() external;
}

/**
 * @title  March 20, 2024 Spark Ethereum Proposal - Raise maximum supply cap in Cap Automator to 6,000 for WBTC and adjust DAI spread to 14% target APY
 * @author Phoenix Labs
 * @dev    This proposal changes the max parameter in supplyCapConfig in CapAutomator for WBTC market
 * Forum:  https://forum.makerdao.com/t/mar-6-2024-proposed-changes-to-sparklend-for-upcoming-spell/23791
 *         https://forum.makerdao.com/t/stability-scope-parameter-changes-11-under-sta-article-3-3/23910
 *         https://forum.makerdao.com/t/introduction-and-initial-parameters-for-ddm-overcollateralized-spark-metamorpho-ethena-vault/23925
 * Votes:  https://vote.makerdao.com/polling/QmVGDsvm
           https://vote.makerdao.com/polling/QmYYoAMe
 */
contract SparkEthereum_20240320 is SparkPayloadEthereum {

    address internal constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address internal constant CAP_AUTOMATOR = 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef;

    address internal constant META_MORPHO_VAULT = 0x73e65DBD630f90604062f6E02fAb9138e713edD9;

    // Formula for 13% target DSR APY (0.122217632961076156494096000)
    // bc -l <<< 'scale=27; (1.000000003875495717943815211 - 1) * 60 * 60 * 24 * 365'
    // Formula for 14% target APY (0.008810629717531220974944000 spread at current DSR):
    // bc -l <<< 'scale=27; (e( l(1.14)/(60 * 60 * 24 * 365) ) - 1) * 60 * 60 * 24 * 365 - 0.122217632961076156494096000'
    address internal constant DAI_IRM = 0x883b03288D1827066C57E5db96661aB994Ef3800;

    function _postExecute()
        internal override
    {
        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: WBTC, max: 6_000, gap: 500, increaseCooldown: 12 hours});

        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            DAI,
            DAI_IRM
        );

        IOwnable(META_MORPHO_VAULT).acceptOwnership();
    }

}
