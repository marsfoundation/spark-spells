// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadGoerli, IEngine, Rates, EngineFlags } from '../../SparkPayloadGoerli.sol';

/**
 * @title Freeze sDAI on Spark Goerli
 * @author Phoenix Labs
 * @dev This proposal freezes the sDAI market.
 */
contract SparkGoerli_20230712 is SparkPayloadGoerli {

    address public constant sDAI = 0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C;

    function _postExecute() internal override {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveFreeze(
            sDAI,
            true
        );
    }

}
