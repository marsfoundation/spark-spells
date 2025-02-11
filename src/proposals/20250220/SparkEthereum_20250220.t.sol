// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Arbitrum }              from 'spark-address-registry/Arbitrum.sol';
import { Ethereum }              from 'spark-address-registry/Ethereum.sol';
import { Base }                  from 'spark-address-registry/Base.sol';
import { MainnetController }     from 'spark-alm-controller/src/MainnetController.sol';
import { ForeignController }     from 'spark-alm-controller/src/ForeignController.sol';
import { IRateLimits }           from 'spark-alm-controller/src/interfaces/IRateLimits.sol';
import { RateLimitHelpers }      from 'spark-alm-controller/src/RateLimitHelpers.sol';
import { IAaveOracle }           from 'sparklend-v1-core/contracts/interfaces/IAaveOracle.sol';
import { IMetaMorpho }           from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';

import { CCTPForwarder }         from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";

import { SparkTestBase } from 'src/SparkTestBase.sol';
import { ChainIdUtils }  from 'src/libraries/ChainId.sol';
import { ReserveConfig } from '../../ProtocolV3TestBase.sol';

interface DssAutoLineLike {
    function setIlk(bytes32 ilk, uint256 line, uint256 gap, uint256 ttl) external;
    function exec(bytes32 ilk) external;
}

interface IArbitrumTokenBridge {
    function registerToken(address l1Token, address l2Token) external;
    function file(bytes32 what, address data) external;
}

interface IAuthLike {
    function rely(address usr) external;
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
        // TODO verify this matches the Sky Core spell

        // Mainnet
        vm.startPrank(Ethereum.PAUSE_PROXY);

        // Increase vault to 5b max line, 500m gap
        DssAutoLineLike(AUTO_LINE).setIlk(ALLOCATOR_ILK, 5_000_000_000e45, 500_000_000e45, 24 hours);
        DssAutoLineLike(AUTO_LINE).exec(ALLOCATOR_ILK);

        // Activate the token bridge
        IArbitrumTokenBridge(Ethereum.ARBITRUM_TOKEN_BRIDGE).registerToken(Ethereum.USDS, Arbitrum.USDS);
        IArbitrumTokenBridge(Ethereum.ARBITRUM_TOKEN_BRIDGE).registerToken(Ethereum.SUSDS, Arbitrum.SUSDS);
        IArbitrumTokenBridge(Ethereum.ARBITRUM_TOKEN_BRIDGE).file("escrow", Ethereum.ARBITRUM_ESCROW);

        vm.stopPrank();

        chainSpellMetadata[ChainIdUtils.ArbitrumOne()].domain.selectFork();

        // Arbitrum Sky Core spell configuration
        vm.startPrank(Arbitrum.SKY_GOV_RELAY);

        IArbitrumTokenBridge(Arbitrum.TOKEN_BRIDGE).registerToken(Ethereum.USDS, Arbitrum.USDS);
        IArbitrumTokenBridge(Arbitrum.TOKEN_BRIDGE).registerToken(Ethereum.SUSDS, Arbitrum.SUSDS);
        IAuthLike(Arbitrum.USDS).rely(Arbitrum.TOKEN_BRIDGE);
        IAuthLike(Arbitrum.SUSDS).rely(Arbitrum.TOKEN_BRIDGE);

        vm.stopPrank();

        chainSpellMetadata[ChainIdUtils.Ethereum()].domain.selectFork();
    }

    function test_ETHEREUM_susdsOnboarding() public onChain(ChainIdUtils.Ethereum()) {
        _assertERC4626Onboarding({
            vault:                 Ethereum.SUSDS,
            expectedDepositAmount: 50_000_000e18,
            depositMax:            type(uint256).max,
            depositSlope:          0
        });
    }

    function test_ETHEREUM_ARBITRUM_sparkLiquidityLayerE2E() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        chainSpellMetadata[ChainIdUtils.ArbitrumOne()].domain.selectFork();

        // Deposit 10m USDS and 10m sUSDS into the PSM
        vm.startPrank(Arbitrum.ALM_RELAYER);
        ForeignController(Arbitrum.ALM_CONTROLLER).depositPSM(Arbitrum.USDS,  10_000_000e18);
        ForeignController(Arbitrum.ALM_CONTROLLER).depositPSM(Arbitrum.SUSDS, 10_000_000e18);
        vm.stopPrank();

        chainSpellMetadata[ChainIdUtils.Ethereum()].domain.selectFork();

        // Clear out the old logs to prevent MemoryOOG error with CCTP message relay
        _clearLogs();

        // Mint and bridge 10m USDC
        uint256 usdcAmount = 10_000_000e6;
        uint256 usdcSeed   = 1e6;

        vm.startPrank(Ethereum.ALM_RELAYER);
        MainnetController(Ethereum.ALM_CONTROLLER).mintUSDS(usdcAmount * 1e12);
        MainnetController(Ethereum.ALM_CONTROLLER).swapUSDSToUSDC(usdcAmount);
        MainnetController(Ethereum.ALM_CONTROLLER).transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE);
        vm.stopPrank();

        chainSpellMetadata[ChainIdUtils.ArbitrumOne()].domain.selectFork();

        assertEq(IERC20(Arbitrum.USDC).balanceOf(Arbitrum.ALM_PROXY), 0);
        assertEq(IERC20(Arbitrum.USDC).balanceOf(Arbitrum.PSM3),      usdcSeed);

        _relayMessageOverBridges();

        assertEq(IERC20(Arbitrum.USDC).balanceOf(Arbitrum.ALM_PROXY), usdcAmount);
        assertEq(IERC20(Arbitrum.USDC).balanceOf(Arbitrum.PSM3),      usdcSeed);

        vm.startPrank(Arbitrum.ALM_RELAYER);
        ForeignController(Arbitrum.ALM_CONTROLLER).depositPSM(Arbitrum.USDC, usdcAmount);
        vm.stopPrank();

        assertEq(IERC20(Arbitrum.USDC).balanceOf(Arbitrum.ALM_PROXY), 0);
        assertEq(IERC20(Arbitrum.USDC).balanceOf(Arbitrum.PSM3),      usdcSeed + usdcAmount);
    }

}
