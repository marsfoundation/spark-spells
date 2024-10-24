// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import { AllocatorInit, AllocatorIlkConfig } from "dss-allocator/deploy/AllocatorInit.sol";

import {
    AllocatorIlkInstance,
    AllocatorSharedInstance
} from "dss-allocator/deploy/AllocatorInstances.sol";

import { AllocatorDeploy } from "dss-allocator/deploy/AllocatorDeploy.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { ISUsds } from "sdai/src/ISUsds.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { Bridge }                from "xchain-helpers/src/testing/Bridge.sol";
import { CCTPForwarder }         from "xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { Domain, DomainHelpers } from "xchain-helpers/src/testing/Domain.sol";

import { MainnetControllerDeploy } from "deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "deploy/ControllerInstance.sol";

import { MainnetControllerInit,
    MintRecipient,
    RateLimitData
} from "deploy/ControllerInit.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { RateLimits }        from "src/RateLimits.sol";
import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";
import { MainnetController } from "src/MainnetController.sol";

interface IChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface IBufferLike {
    function approve(address, address, uint256) external;
}

interface IPSMLike {
    function bud(address) external view returns (uint256);
    function pocket() external view returns (address);
    function kiss(address) external;
    function rush() external view returns (uint256);
}

interface IVaultLike {
    function rely(address) external;
    function wards(address) external returns (uint256);
}

contract ForkTestBase is DssTest {

    using DomainHelpers for *;

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    bytes32 constant ilk                = "ILK-A";
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 constant PSM_ILK = 0x4c4954452d50534d2d555344432d410000000000000000000000000000000000;

    uint256 constant INK           = 1e12 * 1e18;  // Ink initialization amount
    uint256 constant SEVEN_PCT_APY = 1.000000002145441671308778766e27;  // 7% APY (current DSR)
    uint256 constant EIGHT_PCT_APY = 1.000000002440418608258400030e27;  // 8% APY (current DSR + 1%)

    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    bytes32 CONTROLLER;
    bytes32 FREEZER;
    bytes32 RELAYER;

    /**********************************************************************************************/
    /*** Mainnet addresses/constants                                                            ***/
    /**********************************************************************************************/

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address constant CCTP_MESSENGER = Ethereum.CCTP_TOKEN_MESSENGER;
    address constant DAI_USDS       = Ethereum.DAI_USDS;
    address constant PAUSE_PROXY    = Ethereum.PAUSE_PROXY;
    address constant PSM            = Ethereum.PSM;
    address constant SPARK_PROXY    = Ethereum.SPARK_PROXY;

    IERC20 constant dai   = IERC20(Ethereum.DAI);
    IERC20 constant usdc  = IERC20(Ethereum.USDC);
    IERC20 constant usds  = IERC20(Ethereum.USDS);
    ISUsds constant susds = ISUsds(Ethereum.SUSDS);

    IPSMLike constant psm = IPSMLike(PSM);

    address POCKET;
    address USDS_JOIN;

    DssInstance dss;  // Mainnet DSS

    /**********************************************************************************************/
    /*** ALM system and allocation system deployments                                           ***/
    /**********************************************************************************************/

    ALMProxy          almProxy;
    RateLimits        rateLimits;
    MainnetController mainnetController;

    address buffer;
    address vault;

    /**********************************************************************************************/
    /*** Bridging setup                                                                         ***/
    /**********************************************************************************************/

    Bridge bridge;
    Domain source;
    Domain destination;

    /**********************************************************************************************/
    /*** Cached mainnet state variables                                                         ***/
    /**********************************************************************************************/

    uint256 DAI_BAL_PSM;
    uint256 DAI_SUPPLY;
    uint256 USDC_BAL_PSM;
    uint256 USDC_SUPPLY;
    uint256 USDS_SUPPLY;
    uint256 USDS_BAL_SUSDS;
    uint256 VAT_DAI_USDS_JOIN;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {

        /*** Step 1: Set up environment, cast addresses ***/

        source = getChain("mainnet").createSelectFork(20917850);  //  October 7, 2024

        dss = MCD.loadFromChainlog(LOG);

        USDS_JOIN = IChainlogLike(LOG).getAddress("USDS_JOIN");
        POCKET    = IChainlogLike(LOG).getAddress("MCD_LITE_PSM_USDC_A_POCKET");

        DAI_BAL_PSM       = dai.balanceOf(PSM);
        DAI_SUPPLY        = dai.totalSupply();
        USDC_BAL_PSM      = usdc.balanceOf(POCKET);
        USDC_SUPPLY       = usdc.totalSupply();
        USDS_SUPPLY       = usds.totalSupply();
        USDS_BAL_SUSDS    = usds.balanceOf(address(susds));
        VAT_DAI_USDS_JOIN = dss.vat.dai(USDS_JOIN);

        /*** Step 2: Deploy and configure allocation system ***/

        AllocatorSharedInstance memory sharedInst
            = AllocatorDeploy.deployShared(address(this), Ethereum.PAUSE_PROXY);

        AllocatorIlkInstance memory ilkInst = AllocatorDeploy.deployIlk({
            deployer : address(this),
            owner    : Ethereum.PAUSE_PROXY,
            roles    : sharedInst.roles,
            ilk      : ilk,
            usdsJoin : USDS_JOIN
        });

        AllocatorIlkConfig memory ilkConfig = AllocatorIlkConfig({
            ilk            : ilk,
            duty           : EIGHT_PCT_APY,
            maxLine        : 100_000_000 * RAD,
            gap            : 10_000_000 * RAD,
            ttl            : 6 hours,
            allocatorProxy : Ethereum.SPARK_PROXY,
            ilkRegistry    : IChainlogLike(LOG).getAddress("ILK_REGISTRY")
        });

        vm.startPrank(Ethereum.PAUSE_PROXY);
        AllocatorInit.initShared(dss, sharedInst);
        AllocatorInit.initIlk(dss, sharedInst, ilkInst, ilkConfig);
        vm.stopPrank();

        buffer = ilkInst.buffer;
        vault  = ilkInst.vault;

        /*** Step 3: Deploy and configure ALM system ***/

        ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull({
            admin  : Ethereum.SPARK_PROXY,
            vault  : ilkInst.vault,
            psm    : Ethereum.PSM,
            daiUsds: Ethereum.DAI_USDS,
            cctp   : Ethereum.CCTP_TOKEN_MESSENGER,
            susds  : Ethereum.SUSDS
        });

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        rateLimits        = RateLimits(controllerInst.rateLimits);
        mainnetController = MainnetController(controllerInst.controller);

        CONTROLLER = almProxy.CONTROLLER();
        FREEZER    = mainnetController.FREEZER();
        RELAYER    = mainnetController.RELAYER();

        MainnetControllerInit.AddressParams memory addresses = MainnetControllerInit.AddressParams({
            admin         : Ethereum.SPARK_PROXY,
            freezer       : freezer,
            relayer       : relayer,
            oldController : address(0),
            psm           : Ethereum.PSM,
            vault         : vault,
            buffer        : buffer,
            cctpMessenger : Ethereum.CCTP_TOKEN_MESSENGER,
            dai           : Ethereum.DAI,
            daiUsds       : Ethereum.DAI_USDS,
            usdc          : Ethereum.USDC,
            usds          : Ethereum.USDS,
            susds         : Ethereum.SUSDS
        });

        RateLimitData memory usdsMintData = RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        RateLimitData memory standardUsdcData = RateLimitData({
            maxAmount : 5_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        MainnetControllerInit.InitRateLimitData memory rateLimitData
            = MainnetControllerInit.InitRateLimitData({
                usdsMintData         : usdsMintData,
                usdsToUsdcData       : standardUsdcData,
                usdcToCctpData       : standardUsdcData,
                cctpToBaseDomainData : standardUsdcData
            });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        });

        vm.prank(Ethereum.PAUSE_PROXY);
        MainnetControllerInit.pauseProxyInit(Ethereum.PSM, controllerInst.almProxy);

        vm.startPrank(Ethereum.SPARK_PROXY);
        MainnetControllerInit.subDaoInitFull(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
        vm.stopPrank();

        /*** Step 4: Label addresses ***/

        vm.label(buffer,         "buffer");
        vm.label(address(susds), "susds");
        vm.label(address(usdc),  "usdc");
        vm.label(address(usds),  "usds");
        vm.label(vault,          "vault");
    }

}
