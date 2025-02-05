// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum }             from 'spark-address-registry/Ethereum.sol';
import { SparkPayloadEthereum } from "../../SparkPayloadEthereum.sol";

/**
 * @title  Feb 20, 2025 Spark Ethereum Proposal
 * @notice Spark Liquidity Layer: Onboard Arbitrum One, Mint 100m USDS worth of sUSDS into Base
 *         SparkLend: Increase weETH supply cap parameters
 * @author Phoenix Labs
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkEthereum_20250220 is SparkPayloadEthereum {

    constructor() {
        PAYLOAD_BASE     = address(0);
        PAYLOAD_ARBITRUM = address(0);
    }

}
