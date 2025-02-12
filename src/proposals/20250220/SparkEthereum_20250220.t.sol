// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";
import { IERC20 }   from "forge-std/interfaces/IERC20.sol";

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

    function test_ETHEREUM_WEETHChanges() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        
        _assertSupplyCapConfig(Ethereum.WEETH, 200_000, 5_000, 12 hours);

        executeAllPayloadsAndBridges();

        _assertSupplyCapConfig(Ethereum.WEETH, 500_000, 10_000, 12 hours);
    }

    function test_ETHEREUM_susdsOnboarding() public onChain(ChainIdUtils.Ethereum()) {
        _assertERC4626Onboarding({
            vault:                 Ethereum.SUSDS,
            expectedDepositAmount: 50_000_000e18,
            depositMax:            type(uint256).max,
            depositSlope:          0
        });
    }

    function test_BASE_psmRateLimitChanges() public onChain(ChainIdUtils.Base()) {
        bytes32 usdcDepositKey = RateLimitHelpers.makeAssetKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_PSM_DEPOSIT(),
            Base.USDC
        );
        bytes32 usdcWithdrawKey = RateLimitHelpers.makeAssetKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_PSM_WITHDRAW(),
            Base.USDC
        );
        bytes32 usdsDepositKey = RateLimitHelpers.makeAssetKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_PSM_DEPOSIT(),
            Base.USDS
        );
        bytes32 susdsDepositKey = RateLimitHelpers.makeAssetKey(
            ForeignController(Base.ALM_CONTROLLER).LIMIT_PSM_DEPOSIT(),
            Base.SUSDS
        );

        _assertRateLimit(usdcDepositKey,  4_000_000e6, 2_000_000e6 / uint256(1 days));
        _assertRateLimit(usdcWithdrawKey, 7_000_000e6, 2_000_000e6 / uint256(1 days));
        _assertRateLimit(usdsDepositKey,  5_000_000e18, 2_000_000e18 / uint256(1 days));
        _assertRateLimit(susdsDepositKey, 8_000_000e18, 2_000_000e18 / uint256(1 days));

        executeAllPayloadsAndBridges();

        _assertRateLimit(usdcDepositKey,  50_000_000e6, 50_000_000e6 / uint256(1 days));
        _assertRateLimit(usdcWithdrawKey, 50_000_000e6, 50_000_000e6 / uint256(1 days));
        _assertUnlimitedRateLimit(usdsDepositKey);
        _assertUnlimitedRateLimit(susdsDepositKey);
    }

    function test_ETHEREUM_arbitrumCctpConfiguration() public onChain(ChainIdUtils.Ethereum()) {
        bytes32 arbitrumKey = RateLimitHelpers.makeDomainKey(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE
        );

        _assertRateLimit(arbitrumKey, 0, 0);
        assertEq(MainnetController(Ethereum.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE), bytes32(0));

        executeAllPayloadsAndBridges();

        _assertRateLimit(arbitrumKey, 50_000_000e6, 25_000_000e6 / uint256(1 days));
        assertEq(MainnetController(Ethereum.ALM_CONTROLLER).mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE), bytes32(uint256(uint160(Arbitrum.ALM_PROXY))));
    }

    function test_ETHEREUM_ARBITRUM_sparkLiquidityLayerE2E() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        uint256 susdsShares        = IERC4626(Ethereum.SUSDS).convertToShares(100_000_000e18);
        uint256 susdsDepositShares = IERC4626(Ethereum.SUSDS).convertToShares(10_000_000e18);

        chainSpellMetadata[ChainIdUtils.ArbitrumOne()].domain.selectFork();

        assertEq(IERC20(Arbitrum.USDS).balanceOf(Arbitrum.ALM_PROXY),  100_000_000e18);
        assertEq(IERC20(Arbitrum.SUSDS).balanceOf(Arbitrum.ALM_PROXY), susdsShares);
        assertEq(IERC20(Arbitrum.USDS).balanceOf(Arbitrum.PSM3),  0);
        assertEq(IERC20(Arbitrum.SUSDS).balanceOf(Arbitrum.PSM3), 0);

        // Deposit 10m USDS and 10m sUSDS into the PSM
        vm.startPrank(Arbitrum.ALM_RELAYER);
        ForeignController(Arbitrum.ALM_CONTROLLER).depositPSM(Arbitrum.USDS,  10_000_000e18);
        ForeignController(Arbitrum.ALM_CONTROLLER).depositPSM(Arbitrum.SUSDS, susdsDepositShares);
        vm.stopPrank();

        assertEq(IERC20(Arbitrum.USDS).balanceOf(Arbitrum.ALM_PROXY),  90_000_000e18);
        assertEq(IERC20(Arbitrum.SUSDS).balanceOf(Arbitrum.ALM_PROXY), susdsShares - susdsDepositShares);
        assertEq(IERC20(Arbitrum.USDS).balanceOf(Arbitrum.PSM3),  10_000_000e18);
        assertEq(IERC20(Arbitrum.SUSDS).balanceOf(Arbitrum.PSM3), susdsDepositShares);

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
