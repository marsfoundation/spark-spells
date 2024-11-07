// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { CCTPForwarder }         from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { Bridge }                from "xchain-helpers/testing/Bridge.sol";
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { CCTPBridgeTesting }     from "xchain-helpers/testing/bridges/CCTPBridgeTesting.sol";
import { OptimismBridgeTesting } from "xchain-helpers/testing/bridges/OptimismBridgeTesting.sol";

import { IALMProxy }         from "spark-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "spark-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "spark-alm-controller/src/MainnetController.sol";
import { ForeignController } from "spark-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "spark-alm-controller/src/RateLimitHelpers.sol";

interface IVatLike {
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

interface IPSMLike {
    function convertToShares(address, uint256) external view returns (uint256);
    function convertToAssetValue(uint256) external view returns (uint256);
    function shares(address) external view returns (uint256);
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    ) external returns (uint256 amountOut);
}

interface IVariableKinkIRM {
    function getVariableRateSlope1Spread() external view returns (int256);
}

contract SparkEthereum_20241114Test is SparkEthereumTestBase {

    using DomainHelpers         for *;
    using OptimismBridgeTesting for *;

    address internal constant PT_26DEC2024_PRICE_FEED  = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address internal constant PT_SUSDE_26DEC2024       = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;

    address internal constant PT_27MAR2025_PRICE_FEED  = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address internal constant PT_SUSDE_27MAR2025       = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;

    address internal constant OLD_WETH_INTEREST_RATE_STRATEGY = 0x6fd32465a23aa0DBaE0D813B7157D8CB2b08Dae4;
    address internal constant NEW_WETH_INTEREST_RATE_STRATEGY = 0xf4268AeC16d13446381F8a2c9bB05239323756ca;

    uint256 internal constant SUSDS_DEPOSIT_AMOUNT = 8_000_000e18;
    uint256 internal constant USDS_BRIDGE_AMOUNT   = 1_000_000e18;

    address internal constant FREEZER = 0x90D8c80C028B4C09C0d8dcAab9bbB057F0513431;  // Gov. facilitator multisig
    address internal constant RELAYER = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;  // Same address on all chains

    address internal constant DEPLOYER = 0x6F3066538A648b9CFad0679DF0a7e40882A23AA4;

    Domain mainnet;
    Domain base;

    Bridge nativeBridge;
    Bridge cctpBridge;

    address basePayload;

    constructor() {
        id = '20241114';
    }

    function setUp() public {
        mainnet = getChain('mainnet').createFork(21122303);  // Nov 5, 2024
        base    = getChain('base').createFork(22015320);     // Nov 5, 2024

        mainnet.selectFork();
        payload = deployPayload();

        // TODO replace this with the actual address when deployed
        base.selectFork();
        basePayload = deployPayloadBase();

        nativeBridge = OptimismBridgeTesting.createNativeBridge(mainnet, base);
        cctpBridge   = CCTPBridgeTesting.createCircleBridge(mainnet, base);

        mainnet.selectFork();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testWBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wbtcConfig = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold, 70_00);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        wbtcConfig.liquidationThreshold = 65_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
    }

    function testMorphoVaults() public {
        MarketParams memory ptUsde26Dec = MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_26DEC2024,
            oracle:          PT_26DEC2024_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });
        MarketParams memory ptUsde27Mar = MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_27MAR2025,
            oracle:          PT_27MAR2025_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        _assertMorphoCap(ptUsde26Dec, 100_000_000e18);
        _assertMorphoCap(ptUsde27Mar, 100_000_000e18);

        executePayload(payload);

        _assertMorphoCap(ptUsde26Dec, 100_000_000e18, 250_000_000e18);
        _assertMorphoCap(ptUsde27Mar, 100_000_000e18, 200_000_000e18);

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        skip(1 days);

        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptUsde26Dec);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptUsde27Mar);

        _assertMorphoCap(ptUsde26Dec, 250_000_000e18);
        _assertMorphoCap(ptUsde27Mar, 200_000_000e18);
    }

    function testWETHInterestRateUpdate() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');

        assertEq(wethConfigBefore.interestRateStrategy, OLD_WETH_INTEREST_RATE_STRATEGY);

        uint256 expectedOldSlope1 = 0.028991774151952311e27;
        InterestStrategyValues memory values = InterestStrategyValues({
            addressesProvider:             address(poolAddressesProvider),
            optimalUsageRatio:             0.9e27,
            optimalStableToTotalDebtRatio: 0,
            baseStableBorrowRate:          expectedOldSlope1,
            stableRateSlope1:              0,
            stableRateSlope2:              0,
            baseVariableBorrowRate:        0,
            variableRateSlope1:            expectedOldSlope1,
            variableRateSlope2:            1.2e27
        });
        _validateInterestRateStrategy(
            wethConfigBefore.interestRateStrategy,
            OLD_WETH_INTEREST_RATE_STRATEGY,
            values
        );

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory wethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WETH');

        uint256 expectedSlope1 = expectedOldSlope1 - 0.005e27;
        assertEq(expectedSlope1, 0.023991774151952311e27);
        assertEq(
            IVariableKinkIRM(NEW_WETH_INTEREST_RATE_STRATEGY).getVariableRateSlope1Spread(),
            -0.005e27
        );

        values.baseStableBorrowRate = expectedSlope1;
        values.variableRateSlope1   = expectedSlope1;
        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            NEW_WETH_INTEREST_RATE_STRATEGY,
            values
        );
    }

    function testWSTETHBorrowCapUpdate() public {
        _assertBorrowCapConfig({
            asset:            Ethereum.WSTETH,
            max:              3_000,
            gap:              100,
            increaseCooldown: 12 hours
        });

        executePayload(payload);

        _assertBorrowCapConfig({
            asset:            Ethereum.WSTETH,
            max:              100_000,
            gap:              5_000,
            increaseCooldown: 12 hours
        });
    }

    function testALMControllerDeployment() public {
        // Copied from the init library, but no harm checking this here
        IALMProxy         almProxy   = IALMProxy(Ethereum.ALM_PROXY);
        IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        assertEq(almProxy.hasRole(0x0, Ethereum.SPARK_PROXY),   true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Ethereum.SPARK_PROXY), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Ethereum.SPARK_PROXY), true, "incorrect-admin-controller");

        assertEq(almProxy.hasRole(0x0, DEPLOYER),   false, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, DEPLOYER), false, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, DEPLOYER), false, "incorrect-admin-controller");

        assertEq(address(controller.proxy()),      Ethereum.ALM_PROXY,            "incorrect-almProxy");
        assertEq(address(controller.rateLimits()), Ethereum.ALM_RATE_LIMITS,      "incorrect-rateLimits");
        assertEq(address(controller.vault()),      Ethereum.ALLOCATOR_VAULT,      "incorrect-vault");
        assertEq(address(controller.buffer()),     Ethereum.ALLOCATOR_BUFFER,     "incorrect-buffer");
        assertEq(address(controller.psm()),        Ethereum.PSM,                  "incorrect-psm");
        assertEq(address(controller.daiUsds()),    Ethereum.DAI_USDS,             "incorrect-daiUsds");
        assertEq(address(controller.cctp()),       Ethereum.CCTP_TOKEN_MESSENGER, "incorrect-cctpMessenger");
        assertEq(address(controller.susds()),      Ethereum.SUSDS,                "incorrect-susds");
        assertEq(address(controller.dai()),        Ethereum.DAI,                  "incorrect-dai");
        assertEq(address(controller.usdc()),       Ethereum.USDC,                 "incorrect-usdc");
        assertEq(address(controller.usds()),       Ethereum.USDS,                 "incorrect-usds");

        assertEq(controller.psmTo18ConversionFactor(), 1e12, "incorrect-psmTo18ConversionFactor");

        assertEq(controller.active(), true, "controller-not-active");
    }

    function testALMControllerConfiguration() public {
        IALMProxy         almProxy   = IALMProxy(Ethereum.ALM_PROXY);
        IRateLimits       rateLimits = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        executePayload(payload);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), Ethereum.ALM_CONTROLLER),     true, "incorrect-controller-almProxy");
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Ethereum.ALM_CONTROLLER), true, "incorrect-controller-rateLimits");
        assertEq(controller.hasRole(controller.FREEZER(), FREEZER),                    true, "incorrect-freezer-controller");
        assertEq(controller.hasRole(controller.RELAYER(), RELAYER),                    true, "incorrect-relayer-controller");

        _assertRateLimit(controller.LIMIT_USDC_TO_CCTP(), type(uint256).max, 0);
        _assertRateLimit(
            RateLimitHelpers.makeDomainKey(controller.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            4_000_000e6,
            2_000_000e6 / uint256(1 days)
        );
        _assertRateLimit(controller.LIMIT_USDS_MINT(),    4_000_000e18, 2_000_000e18 / uint256(1 days));
        _assertRateLimit(controller.LIMIT_USDS_TO_USDC(), 4_000_000e6,  2_000_000e6 / uint256(1 days));

        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE), bytes32(uint256(uint160(Base.ALM_PROXY))));
    }

    function testALMControllerStartingTokenState() public {
        IVatLike vat = IVatLike(Ethereum.VAT);

        ( uint256 Art, uint256 rate,, uint256 line, ) = vat.ilks("ALLOCATOR-SPARK-A");

        assertEq(Art,  0);
        assertEq(rate, 1e27);
        assertEq(line, 10_000_000e45);

        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.SPARK_PROXY),  0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.BASE_ESCROW),  0);
        assertEq(IERC20(Ethereum.SUSDS).balanceOf(Ethereum.SPARK_PROXY), 0);
        assertEq(IERC20(Ethereum.SUSDS).balanceOf(Ethereum.BASE_ESCROW), 0);

        executePayload(payload);

        ( Art, rate,, line, ) = vat.ilks("ALLOCATOR-SPARK-A");

        uint256 debt = Art * rate / 1e27;

        assertLt(Art,  9_000_000e18);
        assertGt(Art,  8_950_000e18);
        assertGt(rate, 1e27);
        assertEq(debt, 9_000_000e18);
        assertEq(line, 10_000_000e45);

        // $8m of sUSDS
        uint256 expectedShares = IERC4626(Ethereum.SUSDS).convertToShares(8_000_000e18);

        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.SPARK_PROXY),  0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.BASE_ESCROW),  1_000_000e18);
        assertEq(IERC20(Ethereum.SUSDS).balanceOf(Ethereum.SPARK_PROXY), 0);
        assertEq(IERC20(Ethereum.SUSDS).balanceOf(Ethereum.BASE_ESCROW), expectedShares);
    }

    function _setupCrossChainTest() internal {
        mainnet.selectFork();
        executePayload(payload);
        // TODO use the actual cross-chain message to execute when deployed
        base.selectFork();
        executePayloadBase(basePayload);
    }

    function testDepositUSDSandSUSDSPSM3() public {
        _setupCrossChainTest();

        mainnet.selectFork();

        uint256 mainnetTimestamp = block.timestamp;
        uint256 susdsShares      = IERC4626(Ethereum.SUSDS).convertToShares(SUSDS_DEPOSIT_AMOUNT);

        vm.warp(mainnetTimestamp + 1 days);

        uint256 mainnetSUsdsAssets = IERC4626(Ethereum.SUSDS).convertToAssets(susdsShares);

        base.selectFork();

        vm.warp(mainnetTimestamp + 1 days);

        uint256 susdsPsmShares  = IPSMLike(Base.PSM3).convertToShares(Base.SUSDS, susdsShares);
        uint256 baseSUsdsAssets = IPSMLike(Base.PSM3).convertToAssetValue(susdsPsmShares);

        // Ensure cross-chain accounting is correct at the same timestamp
        assertEq(mainnetSUsdsAssets, baseSUsdsAssets);

        // Bridge assets

        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY),  0);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), 0);

        OptimismBridgeTesting.relayMessagesToDestination(nativeBridge, true);

        // Deposit USDS and sUSDS

        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY),  USDS_BRIDGE_AMOUNT);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), susdsShares);
        assertEq(IERC20(Base.USDS).balanceOf(Base.PSM3),       0);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.PSM3),      0);

        assertEq(IPSMLike(Base.PSM3).shares(Base.ALM_PROXY),  0);

        vm.startPrank(RELAYER);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.USDS,  USDS_BRIDGE_AMOUNT);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.SUSDS, susdsShares);
        vm.stopPrank();

        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY),  0);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), 0);
        assertEq(IERC20(Base.USDS).balanceOf(Base.PSM3),       USDS_BRIDGE_AMOUNT);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.PSM3),      susdsShares);

        // Ensure that value controlled by the ALM proxy in the PSM is equal to total value deposited
        uint256 proxyPsmShares = IPSMLike(Base.PSM3).shares(Base.ALM_PROXY);
        assertEq(proxyPsmShares, susdsPsmShares + 1_000_000e18);
        assertEq(
            IPSMLike(Base.PSM3).convertToAssetValue(proxyPsmShares),
            mainnetSUsdsAssets + 1_000_000e18
        );
    }

    function testDepositUSDCPSM3() public {
        _setupCrossChainTest();

        mainnet.selectFork();
        uint256 susdsShares = IERC4626(Ethereum.SUSDS).convertToShares(SUSDS_DEPOSIT_AMOUNT);

        // Do initial deposit of USDS and sUSDS into PSM3
        base.selectFork();

        OptimismBridgeTesting.relayMessagesToDestination(nativeBridge, true);

        vm.startPrank(RELAYER);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.USDS,  USDS_BRIDGE_AMOUNT);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.SUSDS, susdsShares);
        vm.stopPrank();

        mainnet.selectFork();

        // Mint and bridge USDC
        uint256 usdcAmount = 800_000e6;
        uint256 usdcSeed   = 1e6;

        vm.startPrank(RELAYER);
        MainnetController(Ethereum.ALM_CONTROLLER).mintUSDS(usdcAmount * 1e12);
        MainnetController(Ethereum.ALM_CONTROLLER).swapUSDSToUSDC(usdcAmount);
        MainnetController(Ethereum.ALM_CONTROLLER).transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        base.selectFork();

        assertEq(IERC20(Base.USDC).balanceOf(Base.ALM_PROXY), 0);
        assertEq(IERC20(Base.USDC).balanceOf(Base.PSM3),      usdcSeed);

        CCTPBridgeTesting.relayMessagesToDestination(cctpBridge, true);

        uint256 proxyAssets = IPSMLike(Base.PSM3).convertToAssetValue(IPSMLike(Base.PSM3).shares(Base.ALM_PROXY));

        assertEq(IERC20(Base.USDC).balanceOf(Base.ALM_PROXY), usdcAmount);
        assertEq(IERC20(Base.USDC).balanceOf(Base.PSM3),      usdcSeed);

        vm.startPrank(RELAYER);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.USDC, usdcAmount);
        vm.stopPrank();

        assertEq(IERC20(Base.USDC).balanceOf(Base.ALM_PROXY), 0);
        assertEq(IERC20(Base.USDC).balanceOf(Base.PSM3),      usdcSeed + usdcAmount);

        uint256 proxyAssetsAfter = IPSMLike(Base.PSM3).convertToAssetValue(IPSMLike(Base.PSM3).shares(Base.ALM_PROXY));
        assertEq(proxyAssetsAfter, proxyAssets + usdcAmount * 1e12);
    }

    function testMoveFundsToMainnet() public {
        _setupCrossChainTest();

        mainnet.selectFork();

        address baseWhale = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

        uint256 susdsShares = IERC4626(Ethereum.SUSDS).convertToShares(SUSDS_DEPOSIT_AMOUNT);
        uint256 usdcAmount  = 800_000e6;

        IERC20 usdcBase = IERC20(Base.USDC);
        IERC20 usdc     = IERC20(Ethereum.USDC);

        IVatLike vat = IVatLike(Ethereum.VAT);

        base.selectFork();

        // Perform setup
        // NOTE: Using transfers and deals instead of controller actions + bridging because of OOG error

        vm.prank(baseWhale);
        IERC20(Base.USDC).transfer(Base.ALM_PROXY, usdcAmount);

        deal(Base.USDS,  Base.ALM_PROXY, USDS_BRIDGE_AMOUNT);
        deal(Base.SUSDS, Base.ALM_PROXY, susdsShares);

        // Deposit USDC, sUSDS, and USDS into PSM3

        vm.startPrank(RELAYER);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.USDS,  USDS_BRIDGE_AMOUNT);  // NOTE: Done manually with EOA
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.SUSDS, susdsShares);         // NOTE: Done manually with EOA
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.USDC,  usdcAmount);          // NOTE: Done automatically with Planner
        vm.stopPrank();

        // External user performs a swap, putting the USDC balance over the max, triggering a Planner action to withdraw

        vm.prank(baseWhale);
        usdcBase.transfer(address(this), 399_999e6);

        usdcBase.approve(Base.PSM3, 399_999e6);
        IPSMLike(Base.PSM3).swapExactIn(Base.USDC, Base.USDS, 399_999e6, 0, address(this), 0);

        // Planner performs first action, withdraw from PSM and bridge to mainnet

        mainnet.selectFork();

        assertEq(usdc.balanceOf(Ethereum.ALM_PROXY), 0);

        base.selectFork();

        assertEq(usdcBase.balanceOf(Base.PSM3),      1_200_000e6);
        assertEq(usdcBase.balanceOf(Base.ALM_PROXY), 0);

        vm.startPrank(RELAYER);
        ForeignController(Base.ALM_CONTROLLER).withdrawPSM(Base.USDC, 400_000e6);
        ForeignController(Base.ALM_CONTROLLER).transferUSDCToCCTP(400_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
        vm.stopPrank();

        assertEq(usdcBase.balanceOf(Base.PSM3),      800_000e6);
        assertEq(usdcBase.balanceOf(Base.ALM_PROXY), 0);

        CCTPBridgeTesting.relayMessagesToSource(cctpBridge, true);

        assertEq(usdc.balanceOf(Ethereum.ALM_PROXY), 400_000e6);

        // Planner performs second action, swap USDC to USDS and burn

        skip(2 days);  // Ensure that some time has passed since spell execution and actions

        ( uint256 Art1, uint256 rate1,, uint256 line1, ) = vat.ilks("ALLOCATOR-SPARK-A");

        uint256 debt1 = Art1 * rate1 / 1e27;

        assertLt(Art1,  9_000_000e18);
        assertGt(Art1,  8_950_000e18);
        assertGt(rate1, 1e27);
        assertEq(debt1, 9_000_000e18);
        assertEq(line1, 10_000_000e45);

        assertEq(IERC20(Ethereum.USDC).balanceOf(Ethereum.ALM_PROXY), 400_000e6);
        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.ALM_PROXY), 0);

        vm.startPrank(RELAYER);
        MainnetController(Ethereum.ALM_CONTROLLER).swapUSDCToUSDS(400_000e6);
        MainnetController(Ethereum.ALM_CONTROLLER).burnUSDS(400_000e18);
        vm.stopPrank();

        ( uint256 Art2, uint256 rate2,, uint256 line2, ) = vat.ilks("ALLOCATOR-SPARK-A");

        uint256 debt2 = Art2 * rate2 / 1e27;

        assertLt(Art2,  9_000_000e18 - 400_000e18);
        assertGt(Art2,  8_950_000e18 - 400_000e18);
        assertEq(Art2,  Art1 - 400_000e18 * 1e27 / rate2);
        assertGt(rate2, rate1);
        assertGt(debt2, debt1 - 400_000e18);
        assertLt(debt2, debt1 - 400_000e18 + 4_000e18);  // Some interest has accrued
        assertEq(line2, line1);

        assertEq(IERC20(Ethereum.USDC).balanceOf(Ethereum.ALM_PROXY), 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(Ethereum.ALM_PROXY), 0);
    }

    function deployPayloadBase() internal returns (address) {
        string memory fullName = string(abi.encodePacked('SparkBase_', id));
        return deployCode(string(abi.encodePacked(fullName, '.sol:', fullName)));
    }

    function executePayloadBase(address payloadAddress) internal {
        require(Address.isContract(payloadAddress), "PAYLOAD IS NOT A CONTRACT");
        vm.prank(Base.SPARK_EXECUTOR);
        IExecutor(Base.SPARK_EXECUTOR).executeDelegateCall(
            payloadAddress,
            abi.encodeWithSignature('execute()')
        );
    }

    function _assertRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope
    ) internal {
        IRateLimits.RateLimitData memory rateLimit = IRateLimits(Ethereum.ALM_RATE_LIMITS).getRateLimitData(key);
        assertEq(rateLimit.maxAmount,   maxAmount);
        assertEq(rateLimit.slope,       slope);
        assertEq(rateLimit.lastAmount,  maxAmount);
        assertEq(rateLimit.lastUpdated, block.timestamp);
    }

}
