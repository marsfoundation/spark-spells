// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title Freeze sDAI on Spark Ethereum
 * @author Phoenix Labs
 * @dev This proposal freezes the sDAI market.
 */
contract SparkEthereum_20230712 is SparkPayloadEthereum {

    address public constant sDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    function _postExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveFreeze(
            sDAI,
            true
        );
    }

}
