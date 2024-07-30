// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { Ethereum, SparkPayloadEthereum } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  Aug 08, 2024 Spark Ethereum Proposal
 * @notice Activate Lido LST Interest Rate Model (IRM)
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/jul-27-2024-proposed-changes-to-spark-for-upcoming-spell/24755
 * Vote:   https://vote.makerdao.com/polling/QmdFCRfK
 */
contract SparkEthereum_20240808 is SparkPayloadEthereum {

    address internal constant WETH_IRM = 0x6fd32465a23aa0DBaE0D813B7157D8CB2b08Dae4;

    function _postExecute()
        internal override
    {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.WETH,
            WETH_IRM
        );
    }
}
