// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { SparkPayloadBase } from 'src/SparkPayloadBase.sol';
import { Base }             from 'spark-address-registry/Base.sol';

import { RateLimitHelpers } from 'spark-alm-controller/src/RateLimitHelpers.sol';
import { IRateLimits }      from 'spark-alm-controller/src/interfaces/IRateLimits.sol';

import { IExecutor } from 'spark-gov-relay/src/interfaces/IExecutor.sol';

/**
 * @title  Nov 28, 2024 Spark Ethereum Proposal
 * @notice Increase sUSDS liquidity to Base PSM
 *         Update misconfigured Base executor parameters
 * @author Wonderland
 * Forum:  https://forum.sky.money/t/28-nov-2024-proposed-changes-to-spark-for-upcoming-spell-amendments/25575
 */
contract SparkBase_20241128 is SparkPayloadBase {
    bytes32 public constant LIMIT_PSM_DEPOSIT    = keccak256("LIMIT_PSM_DEPOSIT");

    function execute() external {
        bytes32 rateLimitKey = RateLimitHelpers.makeAssetKey(LIMIT_PSM_DEPOSIT, Base.SUSDS);
        IRateLimits(Base.ALM_RATE_LIMITS).setRateLimitData({
            key: rateLimitKey,
            maxAmount : 98_000_000e18,
            slope     : 2_000_000e18 / uint256(1 days)
        });

        IExecutor(Base.SPARK_EXECUTOR).updateDelay(0);
        IExecutor(Base.SPARK_EXECUTOR).updateGracePeriod(7 days);
    }
}
