// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { SparkPayloadEthereum } from "../../SparkPayloadEthereum.sol";

/**
 * @title  Feb 06, 2025 Spark Ethereum Proposal
 * @notice Spark Liquidity Layer: Onboard Fluid sUSDS
 * @author Wonderland
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkEthereum_20250206 is SparkPayloadEthereum {

    constructor() {
        // TODO: set to Base address when deployed
        PAYLOAD_BASE = address(0);
    }

    function _postExecute() internal override { }

}
