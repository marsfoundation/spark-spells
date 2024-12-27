// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './ProtocolV3TestBase.sol';

import { Base } from 'spark-address-registry/Base.sol';

import { IRateLimits } from "spark-alm-controller/src/interfaces/IRateLimits.sol";

import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { SpellRunner }           from './SpellRunner.sol';
import { CommonSpellAssertions } from './CommonSpellAssertions.sol';
import { SparklendTests }        from './SparklendTests.sol';
import { SparkEthereumTests }    from './SparkEthereumTests.sol';

// REPO ARCHITECTURE TODOs
// TODO: Refactor Mock logic for executor to be more realistic, consider fork + prank.

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

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specifictest contracts
abstract contract SparkTestBase is AdvancedLiquidityManagementTests, SparkEthereumTests, CommonSpellAssertions {
    using DomainHelpers for StdChains.Chain;
    using DomainHelpers for Domain;

    // cant really instruct the compiler to simply use the SparklendTests
    // implementation, so I copied it.
    modifier onChain(ChainId chainId) override(SparklendTests, SpellRunner) {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);
        chainSpellMetadata[chainId].domain.selectFork();
        if(address(pool) == address(0)){
            loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        }
        _;
        chainSpellMetadata[currentChain].domain.selectFork();
    }
}
