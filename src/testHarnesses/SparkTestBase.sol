// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './ProtocolV3TestBase.sol';

import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { ChainIdUtils, ChainId } from "src/libraries/ChainId.sol";

import { SpellRunner }                      from './SpellRunner.sol';
import { CommonSpellAssertions }            from './CommonSpellAssertions.sol';
import { SparkEthereumTests }               from './SparkEthereumTests.sol';
import { AdvancedLiquidityManagementTests } from './AdvancedLiquidityManagementTests.sol';
import { MorphoTests }                      from './MorphoTests.sol';

// REPO ARCHITECTURE TODOs
// TODO: Refactor Mock logic for executor to be more realistic, consider fork + prank.

/// @dev convenience contract meant to be the single point of entry for all
/// spell-specifictest contracts
abstract contract SparkTestBase is
    AdvancedLiquidityManagementTests,
    SparkEthereumTests, // SparkEthereumTests extends SparklendTests
    CommonSpellAssertions,
    MorphoTests
{
    using DomainHelpers for StdChains.Chain;
    using DomainHelpers for Domain;

    modifier onChain(ChainId chainId) override(SpellRunner) {
        ChainId currentChain = ChainIdUtils.fromUint(block.chainid);
        chainSpellMetadata[chainId].domain.selectFork();
        if(address(pool) == address(0)){
            loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        }
        _;
        chainSpellMetadata[currentChain].domain.selectFork();
    }
}
