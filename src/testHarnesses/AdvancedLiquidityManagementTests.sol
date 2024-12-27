// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Base }                  from 'spark-address-registry/Base.sol';
import { Ethereum }              from 'spark-address-registry/Ethereum.sol';
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
        IRateLimits rateLimitsContract;
        if(currentChain == ChainIdUtils.Ethereum()) rateLimitsContract = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        else if(currentChain == ChainIdUtils.Base()) rateLimitsContract = IRateLimits(Base.ALM_RATE_LIMITS);
        else require(false, "ALM/executing on unknown chain");

        IRateLimits.RateLimitData memory rateLimit = rateLimitsContract.getRateLimitData(key);
        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  maxAmount);
        assertEq(rateLimit.lastUpdated, block.timestamp);
    }
}

