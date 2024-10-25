// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IERC20 }   from 'forge-std/interfaces/IERC20.sol';
import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { Ethereum, SparkPayloadEthereum } from 'src/SparkPayloadEthereum.sol';

import { Base } from 'spark-address-registry/Base.sol';

import { CCTPForwarder }     from 'xchain-helpers/forwarders/CCTPForwarder.sol';
import { OptimismForwarder } from 'xchain-helpers/forwarders/OptimismForwarder.sol';

import { AllocatorBuffer } from 'dss-allocator/src/AllocatorBuffer.sol';
import { AllocatorVault }  from 'dss-allocator/src/AllocatorVault.sol';

import {
    ControllerInstance,
    MainnetControllerInit,
    RateLimitData,
    MintRecipient
} from 'lib/spark-alm-controller/deploy/ControllerInit.sol';

interface ITokenBridge {
    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

/**
 * @title  Nov 7, 2024 Spark Ethereum Proposal
 * @notice Activate Spark Liquidity Layer
 * @author Phoenix Labs
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkEthereum_20241107 is SparkPayloadEthereum {

    address constant FREEZER = 0x298b375f24CeDb45e936D7e21d6Eb05e344adFb5;  // Gov. facilitator multisig
    address constant RELAYER = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

    uint256 constant USDS_MINT_AMOUNT     = 9_000_000e18;
    uint256 constant SUSDS_DEPOSIT_AMOUNT = 8_000_000e18;
    uint256 constant USDS_BRIDGE_AMOUNT = 1_000_000e18;

    address constant BASE_PAYLOAD = address(0);

    function _postExecute() internal override {
        // --- Activate Mainnet Controller ---
        RateLimitData memory rateLimitData18 = RateLimitData({
            maxAmount : 1_000_000e18,
            slope     :   500_000e18 / uint256(1 days)
        });
        RateLimitData memory rateLimitData6 = RateLimitData({
            maxAmount : 1_000_000e6,
            slope     :   500_000e6 / uint256(1 days)
        });
        RateLimitData memory unlimitedRateLimit = RateLimitData({
            maxAmount : type(uint256).max,
            slope     : 0
        });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);
        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(Base.ALM_PROXY)))
        });

        MainnetControllerInit.subDaoInitFull({
            addresses: MainnetControllerInit.AddressParams({
                admin         : Ethereum.SPARK_PROXY,
                freezer       : FREEZER,
                relayer       : RELAYER,
                oldController : address(0),
                psm           : Ethereum.PSM,
                vault         : Ethereum.ALLOCATOR_VAULT,
                buffer        : Ethereum.ALLOCATOR_BUFFER,
                cctpMessenger : Ethereum.CCTP_TOKEN_MESSENGER,
                dai           : Ethereum.DAI,
                daiUsds       : Ethereum.DAI_USDS,
                usdc          : Ethereum.USDC,
                usds          : Ethereum.USDS,
                susds         : Ethereum.SUSDS
            }),
            controllerInst: ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : Ethereum.ALM_CONTROLLER,
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            data: MainnetControllerInit.InitRateLimitData({
                usdsMintData         : rateLimitData18,
                usdsToUsdcData       : rateLimitData6,
                usdcToCctpData       : unlimitedRateLimit,
                cctpToBaseDomainData : rateLimitData6
            }),
            mintRecipients: mintRecipients
        });

        // --- Send USDS and sUSDS to Base ---

        // Mint USDS and sUSDS
        AllocatorVault(Ethereum.ALLOCATOR_VAULT).draw(USDS_MINT_AMOUNT);
        AllocatorBuffer(Ethereum.ALLOCATOR_BUFFER).approve(Ethereum.USDS, address(this), USDS_MINT_AMOUNT);
        IERC20(Ethereum.USDS).transferFrom(Ethereum.ALLOCATOR_BUFFER, address(this), USDS_MINT_AMOUNT);
        IERC20(Ethereum.USDS).approve(Ethereum.SUSDS, SUSDS_DEPOSIT_AMOUNT);
        uint256 susdsShares = IERC4626(Ethereum.SUSDS).deposit(SUSDS_DEPOSIT_AMOUNT, address(this));

        // Bridge to Base
        IERC20(Ethereum.USDS).approve(Ethereum.BASE_TOKEN_BRIDGE, USDS_BRIDGE_AMOUNT);
        IERC20(Ethereum.SUSDS).approve(Ethereum.BASE_TOKEN_BRIDGE, susdsShares);
        ITokenBridge(Ethereum.BASE_TOKEN_BRIDGE).bridgeERC20To(Ethereum.USDS, Base.USDS, Base.ALM_PROXY, USDS_BRIDGE_AMOUNT, 5_000_000, "");
        ITokenBridge(Ethereum.BASE_TOKEN_BRIDGE).bridgeERC20To(Ethereum.SUSDS, Base.SUSDS, Base.ALM_PROXY, susdsShares, 5_000_000, "");

        // --- Trigger Base Payload ---
        OptimismForwarder.sendMessageL1toL2({
            l1CrossDomain: OptimismForwarder.L1_CROSS_DOMAIN_BASE,
            target:        Base.SPARK_RECEIVER,
            message:       encodePayloadQueue(BASE_PAYLOAD),
            gasLimit:      5_000_000
        });
    }
    
}
