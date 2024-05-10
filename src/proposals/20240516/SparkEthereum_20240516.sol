// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, Ethereum } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  May 16, 2024 Spark Ethereum Proposal
 * @notice Update DAI IRM.
 * @author Phoenix Labs
 * Forum:  TODO
 */
contract SparkEthereum_20240516 is SparkPayloadEthereum {

    // Per-second APY for DSR comes from: https://github.com/makerdao/spells-mainnet/blob/master/src/test/rates.sol
    // Formula for 8% target DSR APY (0.076961041230036903346080000)
    // bc -l <<< 'scale=27; (1.000000002440418608258400030 - 1) * 60 * 60 * 24 * 365'
    // Formula for 9% target APY (0.009216655128763325601840000 spread at current DSR):
    // bc -l <<< 'scale=27; (e( l(1.09)/(60 * 60 * 24 * 365) ) - 1) * 60 * 60 * 24 * 365 - 0.076961041230036903346080000'
    address internal constant DAI_IRM = 0x5ae77aE8ec1B0F9a741C80A4Cdb876e6b5B619b9;

    function _postExecute()
        internal override
    {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.DAI,
            DAI_IRM
        );
    }

}
