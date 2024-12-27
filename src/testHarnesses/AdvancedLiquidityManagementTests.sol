// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IRateLimits }           from "spark-alm-controller/src/interfaces/IRateLimits.sol";
import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";
import { SpellRunner }           from './SpellRunner.sol';

// TODO: expand on this on https://github.com/marsfoundation/spark-spells/issues/65
abstract contract AdvancedLiquidityManagementTests is SpellRunner {
   function _assertRateLimit(
       bytes32 key,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);
        IRateLimits rateLimitsContract = chainSpellMetadata[currentChain].almRateLimits;
        require(address(rateLimitsContract) != address(0), "ALM/executing on unknown chain");

        IRateLimits.RateLimitData memory rateLimit = rateLimitsContract.getRateLimitData(key);
        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  maxAmount);
        assertEq(rateLimit.lastUpdated, block.timestamp);
    }
}

