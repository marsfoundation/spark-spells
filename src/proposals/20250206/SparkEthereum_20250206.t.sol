// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum }              from 'spark-address-registry/Ethereum.sol';
import { Base }                  from 'spark-address-registry/Base.sol';
import { MainnetController }     from 'spark-alm-controller/src/MainnetController.sol';
import { ForeignController }     from 'spark-alm-controller/src/ForeignController.sol';
import { IRateLimits }           from 'spark-alm-controller/src/interfaces/IRateLimits.sol';
import { RateLimitHelpers }      from 'spark-alm-controller/src/RateLimitHelpers.sol';
import { IERC20 }                from 'lib/erc20-helpers/src/interfaces/IERC20.sol';
import { CCTPForwarder }         from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { Errors }                from 'sparklend-v1-core/contracts/protocol/libraries/helpers/Errors.sol';
import { ReserveConfiguration }  from 'sparklend-v1-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import { DataTypes }             from 'sparklend-v1-core/contracts/protocol/libraries/types/DataTypes.sol';

import { SparkTestBase, InterestStrategyValues } from 'src/SparkTestBase.sol';
import { ChainIdUtils }                          from 'src/libraries/ChainId.sol';
import { ReserveConfig }                         from '../../ProtocolV3TestBase.sol';

contract SparkEthereum_20250206Test is SparkTestBase {
    using DomainHelpers for Domain;

    constructor() {
        id = '20250206';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock: 21717490,
            baseForkBlock:    25304922,
            gnosisForkBlock:  38037888
        });

        deployPayloads();
    }

    function test_ETHEREUM_SLL_FluidsUSDSOnboardingSideEffects() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();
    }

    function test_ETHEREUM_SLL_FluidsUSDSRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();
    }

    function test_BASE_SLL_FluidsUSDSOnboardingSideEffects() public onChain(ChainIdUtils.Base()) {
        executeAllPayloadsAndBridges();
    }

    function test_BASE_SLL_FluidsUSDSRateLimits() public onChain(ChainIdUtils.Base()) {
        executeAllPayloadsAndBridges();
    }

    // TODO: question, is the timeout local to the USDC asset or global to the vault? 
    function test_BASE_IncreaseMorphoTimeout() public onChain(ChainIdUtils.Base()) {
        executeAllPayloadsAndBridges();
    }

}
