// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Arbitrum }              from 'spark-address-registry/Arbitrum.sol';
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

interface DssAutoLineLike {
    function setIlk(bytes32 ilk, uint256 line, uint256 gap, uint256 ttl) external;
    function exec(bytes32 ilk) external;
}

interface IArbitrumTokenBridge {
    function registerToken(address l1Token, address l2Token) external;
}

contract SparkEthereum_20250220Test is SparkTestBase {

    using DomainHelpers for Domain;

    address internal constant AUTO_LINE     = 0xC7Bdd1F2B16447dcf3dE045C4a039A60EC2f0ba3;
    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-SPARK-A";

    constructor() {
        id = '20250220';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock:     21783769,
            baseForkBlock:        26005516,
            gnosisForkBlock:      38037888,
            arbitrumOneForkBlock: 303037117
        });

        deployPayloads();

        // The following is expected to be in the main spell
        vm.startPrank(Ethereum.PAUSE_PROXY);

        // Increase vault to 5b max line, 500m gap
        DssAutoLineLike(AUTO_LINE).setIlk(ALLOCATOR_ILK, 5_000_000_000e45, 500_000_000e45, 24 hours);
        DssAutoLineLike(AUTO_LINE).exec(ALLOCATOR_ILK);

        // Activate the token bridge
        IArbitrumTokenBridge(Ethereum.ARBITRUM_TOKEN_BRIDGE).registerToken(Ethereum.USDS, Arbitrum.USDS);
        IArbitrumTokenBridge(Ethereum.ARBITRUM_TOKEN_BRIDGE).registerToken(Ethereum.SUSDS, Arbitrum.SUSDS);

        vm.stopPrank();
    }

}
