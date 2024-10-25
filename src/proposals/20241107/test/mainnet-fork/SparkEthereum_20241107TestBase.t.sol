// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { AllocatorInit, AllocatorIlkConfig } from "dss-allocator/deploy/AllocatorInit.sol";

import {
    AllocatorIlkInstance,
    AllocatorSharedInstance
} from "dss-allocator/deploy/AllocatorInstances.sol";

import { DssInstance, MCD } from "dss-test/MCD.sol";

import 'src/SparkTestBase.sol';

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface IWardLike {
    function rely(address) external;
}

contract SparkEthereum_20241107TestBase is SparkEthereumTestBase {

    // Constants defined in Oct 31 spell for allocation system init
    address internal constant ALLOCATOR_ROLES          = 0x9A865A710399cea85dbD9144b7a09C889e94E803;
    address internal constant ALLOCATOR_REGISTRY       = 0xCdCFA95343DA7821fdD01dc4d0AeDA958051bB3B;
    address internal constant PIP_ALLOCATOR_SPARK_A    = 0xc7B91C401C02B73CBdF424dFaaa60950d5040dB7;
    address internal constant ALLOCATOR_SPARK_BUFFER   = 0xc395D150e71378B47A1b8E9de0c1a83b75a08324;
    address internal constant ALLOCATOR_SPARK_VAULT    = 0x691a6c29e9e96dd897718305427Ad5D534db16BA;
    address internal constant ALLOCATOR_SPARK_OWNER    = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address internal constant SPARK_ALM_PROXY          = 0x1601843c5E9bC251A3272907010AFa41Fa18347E;

    address internal constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    uint256 internal constant  RAD                  = 1e45;
    uint256 internal constant  FIVE_PT_TWO_PCT_RATE = 1000000001607468111246255079;

    constructor() {
        id = '20241107';
    }

    function setUp() public virtual {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 21044602);  // Oct 25, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    // NOTE: Code taken from WIP Oct 31 spell
    function _executeOct31Spell() internal {
        address ILK_REGISTRY = ChainlogLike(LOG).getAddress("ILK_REGISTRY");

        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        // ---------- Init Allocator ILK for Spark Subdao ----------
        // Forum: TODO
        //
        // Init ALLOCATOR-SPARK-A ilk on vat, jug and spotter
        // Set duty on jug to 5.2%
        // Set line on vat
        // Increase Global Line on vat
        // Setup AutoLine for ALLOCATOR-SPARK-A:
        // line: 10_000_000
        // gap: 2_500_000
        // ttl: 86_400 seconds
        // Set spotter.pip for ALLOCATOR-SPARK-A to AllocatorOracle contract
        // Set spotter.mat for ALLOCATOR-SPARK-A to RAY
        // poke ALLOCATOR-SPARK-A (spotter.poke)
        // Add AllocatorBuffer address to AllocatorRegistry
        // Initiate the allocator vault by calling vat.slip & vat.grab
        // Set jug on AllocatorVault
        // Allow vault to pull funds from the buffer by giving max USDS approval
        // Set the allocator proxy as the ALLOCATOR-SPARK-A ilk admin instead of the Pause Proxy on AllocatorRoles
        // Move ownership of AllocatorVault & AllocatorBuffer to AllocatorProxy (SparkProxy)
        // Add Allocator contracts to chainlog (ALLOCATOR_ROLES, ALLOCATOR_REGISTRY, ALLOCATOR_SPARK_A_VAULT, ALLOCATOR_SPARK_A_BUFFER, PIP_ALLOCATOR_SPARK_A)
        // Add ALLOCATOR-SPARK-A ilk to IlkRegistry

        // Allocator shared contracts instance
        AllocatorSharedInstance memory allocatorSharedInstance = AllocatorSharedInstance({
            oracle:   PIP_ALLOCATOR_SPARK_A,
            roles:    ALLOCATOR_ROLES,
            registry: ALLOCATOR_REGISTRY
        });

        // Allocator ALLOCATOR-SPARK-A ilk contracts instance
        AllocatorIlkInstance memory allocatorIlkInstance = AllocatorIlkInstance({
            owner:  ALLOCATOR_SPARK_OWNER,
            vault:  ALLOCATOR_SPARK_VAULT,
            buffer: ALLOCATOR_SPARK_BUFFER
        });

        // Allocator init config
        AllocatorIlkConfig memory allocatorIlkCfg = AllocatorIlkConfig({
            // Init ilk for ALLOCATOR-SPARK-A
            ilk             : "ALLOCATOR-SPARK-A",
            // jug.duty      -> 5.2%
            duty            : FIVE_PT_TWO_PCT_RATE,
            // Autoline line -> 10_000_000
            maxLine         : 10_000_000 * RAD,
            // Autoline gap  -> 2_500_000
            gap             : 10_000_000 * RAD,  // NOTE: BUG - CHANGED THIS TO 10m
            // Autoline ttl  -> 1 day
            ttl             : 86_400 seconds,
            // Spark Proxy   -> 0x1601843c5E9bC251A3272907010AFa41Fa18347E
            allocatorProxy  : Ethereum.SPARK_PROXY,  // NOTE: BUG - CHANGED THIS TO SPARK_PROXY
            // Ilk Registry  -> 0x5a464c28d19848f44199d003bef5ecc87d090f87
            ilkRegistry     : ILK_REGISTRY
        });

        // Init allocator shared contracts
        AllocatorInit.initShared(dss, allocatorSharedInstance);

        // Init allocator system for ALLOCATOR-SPARK-A ilk
        AllocatorInit.initIlk(dss, allocatorSharedInstance, allocatorIlkInstance, allocatorIlkCfg);
    }

}

contract PostSpellExecutionTestBase is SparkEthereum_20241107TestBase {

    function setUp() public override {
        super.setUp();

        vm.startPrank(Ethereum.PAUSE_PROXY);
        _executeOct31Spell();
        vm.stopPrank();

        skip(10 days);

        executePayload(payload);
    }

}
