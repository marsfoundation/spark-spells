// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { Base }          from 'spark-address-registry/Base.sol';

import { SparkLiquidityLayerHelpers } from "src/libraries/SparkLiquidityLayerHelpers.sol";
import { SparkPayloadBase }           from "../../SparkPayloadBase.sol";

/**
 * @title  Jan 23, 2025 Spark Base Proposal
 * @notice Spark Liquidity Layer: update CCTP limits
 * @author Wonderland
 * Forum:  http://forum.sky.money/t/jan-23-2025-proposed-changes-to-spark-for-upcoming-spell-2/25837
 * Vote:   https://vote.makerdao.com/polling/QmexceBK
 */
contract SparkBase_20250123 is SparkPayloadBase {

    function execute() external {
        SparkLiquidityLayerHelpers.setUSDCToDomainRateLimit(
            Base.ALM_RATE_LIMITS,
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            50_000_000e6,
            uint256(25_000_000e6) / 1 days
        );
    }

}
