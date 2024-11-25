// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { SparkPayloadBase } from 'src/SparkPayloadBase.sol';
import { Base }             from 'spark-address-registry/Base.sol';

import { IExecutor } from 'spark-gov-relay/src/interfaces/IExecutor.sol';

/**
 * @title  Nov 28, 2024 Spark Base Proposal
 * @notice Update misconfigured Base executor parameters
 * @author Wonderland
 * Forum:  https://forum.sky.money/t/28-nov-2024-proposed-changes-to-spark-for-upcoming-spell-amendments/25575
 * Vote:   TODO: polling url (update Base Executor params)
 */
contract SparkBase_20241128 is SparkPayloadBase {
    function execute() external {
        IExecutor(Base.SPARK_EXECUTOR).updateDelay(0);
        IExecutor(Base.SPARK_EXECUTOR).updateGracePeriod(7 days);
    }
}
