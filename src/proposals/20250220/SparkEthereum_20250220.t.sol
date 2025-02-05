// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum }              from 'spark-address-registry/Ethereum.sol';
import { Base }                  from 'spark-address-registry/Base.sol';
import { MainnetController }     from 'spark-alm-controller/src/MainnetController.sol';
import { ForeignController }     from 'spark-alm-controller/src/ForeignController.sol';
import { IRateLimits }           from 'spark-alm-controller/src/interfaces/IRateLimits.sol';
import { RateLimitHelpers }      from 'spark-alm-controller/src/RateLimitHelpers.sol';
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { IAaveOracle }           from 'sparklend-v1-core/contracts/interfaces/IAaveOracle.sol';
import { IMetaMorpho }           from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';

import { SparkTestBase } from 'src/SparkTestBase.sol';
import { ChainIdUtils }  from 'src/libraries/ChainId.sol';
import { ReserveConfig } from '../../ProtocolV3TestBase.sol';

contract SparkEthereum_20250220Test is SparkTestBase {

    using DomainHelpers for Domain;

    constructor() {
        id = '20250220';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock:     21732103,
            baseForkBlock:        25693427,
            gnosisForkBlock:      38037888,
            arbitrumOneForkBlock: 38037888
        });
    }

}
