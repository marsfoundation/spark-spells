// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { CCTPForwarder }         from "xchain-helpers/forwarders/CCTPForwarder.sol";
import { OptimismReceiver }      from "xchain-helpers/receivers/OptimismReceiver.sol";
import { Bridge }                from "xchain-helpers/testing/Bridge.sol";
import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { CCTPBridgeTesting }     from "xchain-helpers/testing/bridges/CCTPBridgeTesting.sol";
import { OptimismBridgeTesting } from "xchain-helpers/testing/bridges/OptimismBridgeTesting.sol";

import { IALMProxy }         from "spark-alm-controller/src/interfaces/IALMProxy.sol";
import { IRateLimits }       from "spark-alm-controller/src/interfaces/IRateLimits.sol";
import { MainnetController } from "spark-alm-controller/src/MainnetController.sol";
import { ForeignController } from "spark-alm-controller/src/ForeignController.sol";
import { RateLimitHelpers }  from "spark-alm-controller/src/RateLimitHelpers.sol";

import { DssSpellAction } from "spells-mainnet/src/DssSpell.sol";

contract SparkEthereum_20241114Test is SparkEthereumTestBase {

    using DomainHelpers         for *;
    using OptimismBridgeTesting for *;

    address constant PT_26DEC2024_PRICE_FEED  = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address constant PT_SUSDE_26DEC2024       = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;

    address constant PT_27MAR2025_PRICE_FEED  = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address constant PT_SUSDE_27MAR2025       = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;

    address constant OLD_WETH_INTEREST_RATE_STRATEGY = 0x6fd32465a23aa0DBaE0D813B7157D8CB2b08Dae4;
    address constant NEW_WETH_INTEREST_RATE_STRATEGY = 0xf4268AeC16d13446381F8a2c9bB05239323756ca;

    uint256 constant SUSDS_DEPOSIT_AMOUNT = 8_000_000e18;
    uint256 constant USDS_BRIDGE_AMOUNT   = 1_000_000e18;

    address constant RELAYER = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;  // Same address on all chains

    Domain mainnet;
    Domain base;

    Bridge nativeBridge;
    Bridge cctpBridge;

    address basePayload;

    constructor() {
        id = '20241114';
    }

    function setUp() public {
        mainnet = getChain('mainnet').createFork(21071612);  // Oct 30, 2024
        base    = getChain('base').createFork(21752609);     // Oct 30, 2024

        mainnet.selectFork();
        payload = deployPayload();

        // TODO replace this with the actual address when deployed
        base.selectFork();
        basePayload = deployPayloadBase();

        nativeBridge = OptimismBridgeTesting.createNativeBridge(mainnet, base);
        cctpBridge = CCTPBridgeTesting.createCircleBridge(mainnet, base);

        mainnet.selectFork();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        // Maker Core spell execution
        skip(1 hours);  // office hours restriction in maker core spell
        address spell = address(new DssSpellAction());
        vm.etch(Ethereum.PAUSE_PROXY, spell.code);
        DssSpellAction(Ethereum.PAUSE_PROXY).execute();
    }

    function testWBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wbtcConfig = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold,   70_00);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        wbtcConfig.liquidationThreshold   = 65_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
    }

    function testMorphoVaults() public {
        MarketParams memory ptUsde26Dec =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_26DEC2024,
            oracle:          PT_26DEC2024_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });
        MarketParams memory ptUsde27Mar =  MarketParams({
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

        uint256 expectedOldSlope1 = 0.028564144275278442e27;
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
        assertEq(expectedSlope1, 0.023564144275278442e27);

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
        IALMProxy almProxy           = IALMProxy(Ethereum.ALM_PROXY);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

        assertEq(almProxy.hasRole(0x0, Ethereum.SPARK_PROXY),   true, "incorrect-admin-almProxy");
        assertEq(rateLimits.hasRole(0x0, Ethereum.SPARK_PROXY), true, "incorrect-admin-rateLimits");
        assertEq(controller.hasRole(0x0, Ethereum.SPARK_PROXY), true, "incorrect-admin-controller");

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
        MainnetController c = MainnetController(Ethereum.ALM_CONTROLLER);

        executePayload(payload);

        _assertRateLimit(c.LIMIT_USDC_TO_CCTP(), type(uint256).max, 0);
        _assertRateLimit(
            RateLimitHelpers.makeDomainKey(c.LIMIT_USDC_TO_DOMAIN(), CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            4_000_000e6,
            2_000_000e6 / uint256(1 days)
        );
        _assertRateLimit(c.LIMIT_USDS_MINT(),    4_000_000e18, 2_000_000e18 / uint256(1 days));
        _assertRateLimit(c.LIMIT_USDS_TO_USDC(), 4_000_000e6,  2_000_000e6 / uint256(1 days));

        assertEq(c.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE), bytes32(uint256(uint160(Base.ALM_PROXY))));
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

        uint256 susdsShares = IERC4626(Ethereum.SUSDS).convertToShares(SUSDS_DEPOSIT_AMOUNT);

        base.selectFork();

        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY),  0);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), 0);

        OptimismBridgeTesting.relayMessagesToDestination(nativeBridge, true);

        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY),  USDS_BRIDGE_AMOUNT);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), susdsShares);

        // Deposit USDS and sUSDS
        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY),  USDS_BRIDGE_AMOUNT);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), susdsShares);
        assertEq(IERC20(Base.USDS).balanceOf(Base.PSM3),       0);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.PSM3),      0);

        vm.startPrank(RELAYER);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.USDS,  USDS_BRIDGE_AMOUNT);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.SUSDS, susdsShares);
        vm.stopPrank();

        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY),  0);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), 0);
        assertEq(IERC20(Base.USDS).balanceOf(Base.PSM3),       USDS_BRIDGE_AMOUNT);
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.PSM3),      susdsShares);
    }

    function testDepositUSDCPSM3() public {
        _setupCrossChainTest();

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

        // FIXME this is causing a MemoryOOG error, doing a workaround for now
        //CCTPBridgeTesting.relayMessagesToDestination(cctpBridge, true);
        vm.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);  // Some USDC whale on Base
        IERC20(Base.USDC).transfer(Base.ALM_PROXY, usdcAmount);

        assertEq(IERC20(Base.USDC).balanceOf(Base.ALM_PROXY), usdcAmount);
        assertEq(IERC20(Base.USDC).balanceOf(Base.PSM3),      usdcSeed);

        vm.startPrank(RELAYER);
        ForeignController(Base.ALM_CONTROLLER).depositPSM(Base.USDC, usdcAmount);
        vm.stopPrank();

        assertEq(IERC20(Base.USDC).balanceOf(Base.ALM_PROXY), 0);
        assertEq(IERC20(Base.USDC).balanceOf(Base.PSM3),      usdcAmount + usdcSeed);
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
