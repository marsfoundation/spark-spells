// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { ICapAutomator } from 'lib/sparklend-cap-automator/src/interfaces/ICapAutomator.sol';
import { SparkPayloadEthereum, Ethereum, IEngine, EngineFlags } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  Jul 11, 2024 Spark Ethereum Proposal
 * @notice Increase Capacity of weETH
 * @author Wonderland
 * Forum:  https://forum.makerdao.com/t/jun-27-2024-proposed-changes-to-spark-for-upcoming-spell/24552
 * Vote:   https://vote.makerdao.com/polling/QmTBsxR5#poll-detail
 */
contract SparkEthereum_20240711 is SparkPayloadEthereum {

    // Per-second APY for DSR comes from: https://github.com/makerdao/spells-mainnet/blob/master/src/test/rates.sol
    // Formula for 7% target DSR APY (0.067658648546393647164576000)
    // bc -l <<< 'scale=27; (1.000000002145441671308778766 - 1) * 60 * 60 * 24 * 365'
    // Formula for 8% target APY (0.009302392683643256181504000 spread at current DSR):
    // bc -l <<< 'scale=27; (e( l(1.08)/(60 * 60 * 24 * 365) ) - 1) * 60 * 60 * 24 * 365 - 0.067658648546393647164576000'
    address internal constant DAI_IRM = 0x92af90912FD747aE836e0E9d5462A210EfE6A881;

    function collateralsUpdates()
        public pure override returns (IEngine.CollateralUpdate[] memory)
    {
        IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](1);

        // Increase weETH isolation mode debt ceiling to 200 million DAI (Increase for 150 million DAI)
        collateralUpdates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WEETH,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    200_000_000,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return collateralUpdates;
    }

    function _postExecute()
        internal override
    {   
        // Decrease DAI rates by 1 percentage point, from 8% to 7%
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.DAI,
            DAI_IRM
        );
        
        // Increase max supply cap to 200,000 weETH (Increase for 150,000 weETH)
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setSupplyCapConfig({asset: Ethereum.WEETH, max: 200_000, gap: 5_000, increaseCooldown: 12 hours});
    }
}
