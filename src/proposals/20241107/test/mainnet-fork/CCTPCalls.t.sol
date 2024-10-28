// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

// import "test/mainnet-fork/ForkTestBase.t.sol";

// import { IERC20 } from "lib/forge-std/src/interfaces/IERC20.sol";

// import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

// import { Base } from "spark-address-registry/Base.sol";

// import { PSM3Deploy }       from "spark-psm/deploy/PSM3Deploy.sol";
// import { IPSM3 }            from "spark-psm/src/PSM3.sol";
// import { MockRateProvider } from "spark-psm/test/mocks/MockRateProvider.sol";

// import { CCTPBridgeTesting } from "xchain-helpers/src/testing/bridges/CCTPBridgeTesting.sol";
import { CCTPForwarder }     from "xchain-helpers/forwarders/CCTPForwarder.sol";

// import { ForeignControllerDeploy } from "deploy/ControllerDeploy.sol";
// import { ControllerInstance }      from "deploy/ControllerInstance.sol";

// import { ForeignControllerInit,
//     MintRecipient,
//     RateLimitData
// } from "deploy/ControllerInit.sol";

// import { ALMProxy }          from "src/ALMProxy.sol";
// import { ForeignController } from "src/ForeignController.sol";
// import { RateLimits }        from "src/RateLimits.sol";
// import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";

import "./SparkEthereum_20241107TestBase.t.sol";

contract MainnetControllerTransferUSDCToCCTPFailureTests is PostSpellExecutionTestBase {

    function setUp() override public {
        super.setUp();

        vm.startPrank(relayer);
        mainnetController.mintUSDS(1_000_000e18);
        mainnetController.swapUSDSToUSDC(1_000_000e6);
        vm.stopPrank();
    }

    function test_transferUSDCToCCTP_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            mainnetController.RELAYER()
        ));
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_transferUSDCToCCTP_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_transferUSDCToCCTP_domainRateLimitedBoundary() external {
        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.transferUSDCToCCTP(1_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        mainnetController.transferUSDCToCCTP(1_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    // NOTE: Skipped this test because CCTP rate limit is unlimited
    // function test_transferUSDCToCCTP_domainRateLimitedBoundary() external {}

    function test_transferUSDCToCCTP_notBaseDomain() external {
        vm.prank(relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        mainnetController.transferUSDCToCCTP(1_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE);
    }

}

// // TODO: Figure out finalized structure for this repo/testing structure wise
// contract BaseChainUSDCToCCTPTestBase is ForkTestBase {

//     using DomainHelpers     for *;
//     using CCTPBridgeTesting for Bridge;

//     /**********************************************************************************************/
//     /*** Constants/state variables                                                              ***/
//     /**********************************************************************************************/

//     address pocket = makeAddr("pocket");

//     /**********************************************************************************************/
//     /*** Base addresses                                                                         ***/
//     /**********************************************************************************************/

//     address constant CCTP_MESSENGER_BASE = Base.CCTP_TOKEN_MESSENGER;
//     address constant SPARK_EXECUTOR      = Base.SPARK_EXECUTOR;
//     address constant SSR_ORACLE          = Base.SSR_AUTH_ORACLE;
//     address constant USDC_BASE           = Base.USDC;

//     /**********************************************************************************************/
//     /*** ALM system deployments                                                                 ***/
//     /**********************************************************************************************/

//     ALMProxy          foreignAlmProxy;
//     RateLimits        foreignRateLimits;
//     ForeignController foreignController;

//     /**********************************************************************************************/
//     /*** Casted addresses for testing                                                           ***/
//     /**********************************************************************************************/

//     IERC20 usdsBase;
//     IERC20 susdsBase;
//     IERC20 usdcBase;

//     MockRateProvider rateProvider;

//     IPSM3 psmBase;

//     uint256 USDC_BASE_SUPPLY;

//     function setUp() public override virtual {
//         super.setUp();

//         /*** Step 1: Set up environment and deploy mocks ***/

//         destination = getChain("base").createSelectFork(20782500);  // October 7, 2024

//         usdsBase  = IERC20(address(new ERC20Mock()));
//         susdsBase = IERC20(address(new ERC20Mock()));
//         usdcBase  = IERC20(USDC_BASE);

//         /*** Step 2: Deploy and configure PSM with a pocket ***/

//         deal(address(usdsBase), address(this), 1e18);  // For seeding PSM during deployment

//         psmBase = IPSM3(PSM3Deploy.deploy(
//             SPARK_EXECUTOR, USDC_BASE, address(usdsBase), address(susdsBase), SSR_ORACLE
//         ));

//         vm.prank(SPARK_EXECUTOR);
//         psmBase.setPocket(pocket);

//         vm.prank(pocket);
//         usdcBase.approve(address(psmBase), type(uint256).max);

//         /*** Step 3: Deploy and configure ALM system ***/

//         ControllerInstance memory controllerInst = ForeignControllerDeploy.deployFull({
//             admin : SPARK_EXECUTOR,
//             psm   : address(psmBase),
//             usdc  : USDC_BASE,
//             cctp  : CCTP_MESSENGER_BASE
//         });

//         foreignAlmProxy   = ALMProxy(payable(controllerInst.almProxy));
//         foreignRateLimits = RateLimits(controllerInst.rateLimits);
//         foreignController = ForeignController(controllerInst.controller);

//         ForeignControllerInit.AddressParams memory addresses = ForeignControllerInit.AddressParams({
//             admin         : SPARK_EXECUTOR,
//             freezer       : freezer,
//             relayer       : relayer,
//             oldController : address(0),  // Empty
//             psm           : address(psmBase),
//             cctpMessenger : CCTP_MESSENGER_BASE,
//             usdc          : USDC_BASE,
//             usds          : address(usdsBase),
//             susds         : address(susdsBase)
//         });

//         RateLimitData memory standardUsdcRateLimitData = RateLimitData({
//             maxAmount : 5_000_000e6,
//             slope     : uint256(1_000_000e6) / 4 hours
//         });

//         RateLimitData memory standardUsdsRateLimitData = RateLimitData({
//             maxAmount : 5_000_000e18,
//             slope     : uint256(1_000_000e18) / 4 hours
//         });

//         RateLimitData memory unlimitedRateLimitData = RateLimitData({
//             maxAmount : type(uint256).max,
//             slope     : 0
//         });

//         ForeignControllerInit.InitRateLimitData memory rateLimitData
//             = ForeignControllerInit.InitRateLimitData({
//                 usdcDepositData          : standardUsdcRateLimitData,
//                 usdcWithdrawData         : standardUsdcRateLimitData,
//                 usdsDepositData          : standardUsdsRateLimitData,
//                 usdsWithdrawData         : unlimitedRateLimitData,
//                 susdsDepositData         : standardUsdsRateLimitData,
//                 susdsWithdrawData        : unlimitedRateLimitData,
//                 usdcToCctpData           : standardUsdcRateLimitData,
//                 cctpToEthereumDomainData : standardUsdcRateLimitData
//             });

//         MintRecipient[] memory mintRecipients = new MintRecipient[](1);

//         mintRecipients[0] = MintRecipient({
//             domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
//             mintRecipient : bytes32(uint256(uint160(address(almProxy))))
//         });

//         vm.startPrank(SPARK_EXECUTOR);
//         ForeignControllerInit.init(addresses, controllerInst, rateLimitData, mintRecipients);
//         vm.stopPrank();

//         USDC_BASE_SUPPLY = usdcBase.totalSupply();

//         source.selectFork();

//         bridge = CCTPBridgeTesting.createCircleBridge(source, destination);

//         vm.prank(SPARK_PROXY);
//         mainnetController.setMintRecipient(
//             CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
//             bytes32(uint256(uint160(address(foreignAlmProxy))))
//         );
//     }

// }

// contract ForeignControllerTransferUSDCToCCTPFailureTests is BaseChainUSDCToCCTPTestBase {

//     using DomainHelpers for *;

//     function setUp( ) public override {
//         super.setUp();
//         destination.selectFork();
//     }

//     function test_transferUSDCToCCTP_notRelayer() external {
//         vm.expectRevert(abi.encodeWithSignature(
//             "AccessControlUnauthorizedAccount(address,bytes32)",
//             address(this),
//             RELAYER
//         ));
//         foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
//     }

//     function test_transferUSDCToCCTP_frozen() external {
//         vm.prank(freezer);
//         foreignController.freeze();

//         vm.prank(relayer);
//         vm.expectRevert("ForeignController/not-active");
//         foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
//     }

//     function test_transferUSDCToCCTP_cctpRateLimitedBoundary() external {
//         vm.startPrank(SPARK_EXECUTOR);

//         // Set this so second modifier will be passed in success case
//         foreignRateLimits.setUnlimitedRateLimitData(
//             RateLimitHelpers.makeDomainKey(
//                 foreignController.LIMIT_USDC_TO_DOMAIN(),
//                 CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
//             )
//         );

//         // Rate limit will be constant 10m (higher than setup)
//         foreignRateLimits.setRateLimitData(foreignController.LIMIT_USDC_TO_CCTP(), 10_000_000e6, 0);

//         // Set this for success case
//         foreignController.setMintRecipient(
//             CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
//             bytes32(uint256(uint160(makeAddr("mintRecipient"))))
//         );

//         vm.stopPrank();

//         deal(address(usdcBase), address(foreignAlmProxy), 10_000_000e6 + 1);

//         vm.startPrank(relayer);
//         vm.expectRevert("RateLimits/rate-limit-exceeded");
//         foreignController.transferUSDCToCCTP(10_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

//         foreignController.transferUSDCToCCTP(10_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
//     }

//     function test_transferUSDCToCCTP_domainRateLimitedBoundary() external {
//         vm.startPrank(SPARK_EXECUTOR);

//         // Set this so first modifier will be passed in success case
//         foreignRateLimits.setUnlimitedRateLimitData(foreignController.LIMIT_USDC_TO_CCTP());

//         // Rate limit will be constant 10m (higher than setup)
//         foreignRateLimits.setRateLimitData(
//             RateLimitHelpers.makeDomainKey(
//                 foreignController.LIMIT_USDC_TO_DOMAIN(),
//                 CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
//             ),
//             10_000_000e6,
//             0
//         );

//         // Set this for success case
//         foreignController.setMintRecipient(
//             CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
//             bytes32(uint256(uint160(makeAddr("mintRecipient"))))
//         );

//         vm.stopPrank();

//         deal(address(usdcBase), address(foreignAlmProxy), 10_000_000e6 + 1);

//         vm.startPrank(relayer);
//         vm.expectRevert("RateLimits/rate-limit-exceeded");
//         foreignController.transferUSDCToCCTP(10_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

//         foreignController.transferUSDCToCCTP(10_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
//     }

//     function test_transferUSDCToCCTP_invalidMintRecipient() external {
//         // Configure to pass modifiers
//         vm.startPrank(SPARK_EXECUTOR);

//         foreignRateLimits.setUnlimitedRateLimitData(
//             RateLimitHelpers.makeDomainKey(
//                 foreignController.LIMIT_USDC_TO_DOMAIN(),
//                 CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE
//             )
//         );

//         foreignRateLimits.setUnlimitedRateLimitData(foreignController.LIMIT_USDC_TO_CCTP());

//         vm.stopPrank();

//         vm.prank(relayer);
//         vm.expectRevert("ForeignController/domain-not-configured");
//         foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE);
//     }

// }

// contract USDCToCCTPIntegrationTests is BaseChainUSDCToCCTPTestBase {

//     using DomainHelpers     for *;
//     using CCTPBridgeTesting for Bridge;

//     event CCTPTransferInitiated(
//         uint64  indexed nonce,
//         uint32  indexed destinationDomain,
//         bytes32 indexed mintRecipient,
//         uint256 usdcAmount
//     );

//     event DepositForBurn(
//         uint64  indexed nonce,
//         address indexed burnToken,
//         uint256 amount,
//         address indexed depositor,
//         bytes32 mintRecipient,
//         uint32  destinationDomain,
//         bytes32 destinationTokenMessenger,
//         bytes32 destinationCaller
//     );

//     function test_transferUSDCToCCTP_sourceToDestination() external {
//         deal(address(usdc), address(almProxy), 1e6);

//         assertEq(usdc.balanceOf(address(almProxy)),          1e6);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

//         assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

//         _expectEthereumCCTPEmit(114_803, 1e6);

//         vm.prank(relayer);
//         mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

//         assertEq(usdc.balanceOf(address(almProxy)),          0);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 1e6);

//         assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

//         destination.selectFork();

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
//         assertEq(usdcBase.balanceOf(address(foreignController)), 0);
//         assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

//         bridge.relayMessagesToDestination(true);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   1e6);
//         assertEq(usdcBase.balanceOf(address(foreignController)), 0);
//         assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY + 1e6);
//     }

//     function test_transferUSDCToCCTP_sourceToDestination_bigTransfer() external {
//         deal(address(usdc), address(almProxy), 2_900_000e6);

//         assertEq(usdc.balanceOf(address(almProxy)),          2_900_000e6);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

//         assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

//         // Will split into 3 separate transactions at max 1m each
//         _expectEthereumCCTPEmit(114_803, 1_000_000e6);
//         _expectEthereumCCTPEmit(114_804, 1_000_000e6);
//         _expectEthereumCCTPEmit(114_805, 900_000e6);

//         vm.prank(relayer);
//         mainnetController.transferUSDCToCCTP(2_900_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

//         assertEq(usdc.balanceOf(address(almProxy)),          0);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 2_900_000e6);

//         assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

//         destination.selectFork();

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
//         assertEq(usdcBase.balanceOf(address(foreignController)), 0);
//         assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

//         bridge.relayMessagesToDestination(true);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   2_900_000e6);
//         assertEq(usdcBase.balanceOf(address(foreignController)), 0);
//         assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY + 2_900_000e6);
//     }

//     function test_transferUSDCToCCTP_sourceToDestination_rateLimited() external {
//         bytes32 key = mainnetController.LIMIT_USDC_TO_CCTP();
//         deal(address(usdc), address(almProxy), 9_000_000e6);

//         vm.startPrank(relayer);

//         assertEq(usdc.balanceOf(address(almProxy)),   9_000_000e6);
//         assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e6);

//         mainnetController.transferUSDCToCCTP(2_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

//         assertEq(usdc.balanceOf(address(almProxy)),   7_000_000e6);
//         assertEq(rateLimits.getCurrentRateLimit(key), 3_000_000e6);

//         vm.expectRevert("RateLimits/rate-limit-exceeded");
//         mainnetController.transferUSDCToCCTP(3_000_001e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

//         mainnetController.transferUSDCToCCTP(3_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

//         assertEq(usdc.balanceOf(address(almProxy)),   4_000_000e6);
//         assertEq(rateLimits.getCurrentRateLimit(key), 0);

//         skip(4 hours);

//         assertEq(usdc.balanceOf(address(almProxy)),   4_000_000e6);
//         assertEq(rateLimits.getCurrentRateLimit(key), 999_999.9936e6);

//         mainnetController.transferUSDCToCCTP(999_999.9936e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

//         assertEq(usdc.balanceOf(address(almProxy)),   3_000_000.0064e6);
//         assertEq(rateLimits.getCurrentRateLimit(key), 0);

//         vm.stopPrank();
//     }

//     function test_transferUSDCToCCTP_destinationToSource() external {
//         destination.selectFork();

//         deal(address(usdcBase), address(foreignAlmProxy), 1e6);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   1e6);
//         assertEq(usdcBase.balanceOf(address(foreignController)), 0);
//         assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

//         assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

//         _expectBaseCCTPEmit(296_114, 1e6);

//         vm.prank(relayer);
//         foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
//         assertEq(usdcBase.balanceOf(address(foreignController)), 0);
//         assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY - 1e6);

//         assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

//         source.selectFork();

//         assertEq(usdc.balanceOf(address(almProxy)),          0);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

//         bridge.relayMessagesToSource(true);

//         assertEq(usdc.balanceOf(address(almProxy)),          1e6);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.totalSupply(),                         USDC_SUPPLY + 1e6);
//     }

//     function test_transferUSDCToCCTP_destinationToSource_bigTransfer() external {
//         destination.selectFork();

//         deal(address(usdcBase), address(foreignAlmProxy), 2_600_000e6);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   2_600_000e6);
//         assertEq(usdcBase.balanceOf(address(foreignController)), 0);
//         assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

//         assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

//         // Will split into three separate transactions at max 1m each
//         _expectBaseCCTPEmit(296_114, 1_000_000e6);
//         _expectBaseCCTPEmit(296_115, 1_000_000e6);
//         _expectBaseCCTPEmit(296_116, 600_000e6);

//         vm.prank(relayer);
//         foreignController.transferUSDCToCCTP(2_600_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
//         assertEq(usdcBase.balanceOf(address(foreignController)), 0);
//         assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY - 2_600_000e6);

//         assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

//         source.selectFork();

//         assertEq(usdc.balanceOf(address(almProxy)),          0);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

//         bridge.relayMessagesToSource(true);

//         assertEq(usdc.balanceOf(address(almProxy)),          2_600_000e6);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.totalSupply(),                         USDC_SUPPLY + 2_600_000e6);
//     }

//     function test_transferUSDCToCCTP_destinationToSource_rateLimited() external {
//         destination.selectFork();

//         bytes32 key = foreignController.LIMIT_USDC_TO_CCTP();
//         deal(address(usdcBase), address(foreignAlmProxy), 9_000_000e6);

//         vm.startPrank(relayer);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)), 9_000_000e6);
//         assertEq(foreignRateLimits.getCurrentRateLimit(key),   5_000_000e6);

//         foreignController.transferUSDCToCCTP(2_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)), 7_000_000e6);
//         assertEq(foreignRateLimits.getCurrentRateLimit(key),   3_000_000e6);

//         vm.expectRevert("RateLimits/rate-limit-exceeded");
//         foreignController.transferUSDCToCCTP(3_000_001e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

//         foreignController.transferUSDCToCCTP(3_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)), 4_000_000e6);
//         assertEq(foreignRateLimits.getCurrentRateLimit(key),   0);

//         skip(4 hours);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)), 4_000_000e6);
//         assertEq(foreignRateLimits.getCurrentRateLimit(key),   999_999.9936e6);

//         foreignController.transferUSDCToCCTP(999_999.9936e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

//         assertEq(usdcBase.balanceOf(address(foreignAlmProxy)), 3_000_000.0064e6);
//         assertEq(foreignRateLimits.getCurrentRateLimit(key),   0);

//         vm.stopPrank();
//     }

//     function _expectEthereumCCTPEmit(uint64 nonce, uint256 amount) internal {
//         // NOTE: Focusing on burnToken, amount, depositor, mintRecipient, and destinationDomain
//         //       for assertions
//         vm.expectEmit(CCTP_MESSENGER);
//         emit DepositForBurn(
//             nonce,
//             address(usdc),
//             amount,
//             address(almProxy),
//             mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
//             CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
//             bytes32(0x0000000000000000000000001682ae6375c4e4a97e4b583bc394c861a46d8962),
//             bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
//         );

//         vm.expectEmit(address(mainnetController));
//         emit CCTPTransferInitiated(
//             nonce,
//             CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
//             mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
//             amount
//         );
//     }

//     function _expectBaseCCTPEmit(uint64 nonce, uint256 amount) internal {
//         // NOTE: Focusing on burnToken, amount, depositor, mintRecipient, and destinationDomain
//         //       for assertions
//         vm.expectEmit(CCTP_MESSENGER_BASE);
//         emit DepositForBurn(
//             nonce,
//             address(usdcBase),
//             amount,
//             address(foreignAlmProxy),
//             foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
//             CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
//             bytes32(0x000000000000000000000000bd3fa81b58ba92a82136038b25adec7066af3155),
//             bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
//         );

//         vm.expectEmit(address(foreignController));
//         emit CCTPTransferInitiated(
//             nonce,
//             CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
//             foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
//             amount
//         );
//     }

// }
