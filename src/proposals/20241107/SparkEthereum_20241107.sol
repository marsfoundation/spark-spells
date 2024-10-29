// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IERC20 }   from 'forge-std/interfaces/IERC20.sol';
import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { Ethereum, SparkPayloadEthereum, IEngine, EngineFlags } from 'src/SparkPayloadEthereum.sol';

import { ICapAutomator } from "lib/sparklend-cap-automator/src/interfaces/ICapAutomator.sol";

import { IMetaMorpho, MarketParams } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';

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

    address internal constant PT_26DEC2024_PRICE_FEED = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address internal constant PT_SUSDE_26DEC2024      = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;

    address internal constant WETH_IRM = 0xf4268AeC16d13446381F8a2c9bB05239323756ca;

    address internal constant FREEZER = 0x90D8c80C028B4C09C0d8dcAab9bbB057F0513431;  // Gov. facilitator multisig
    address internal constant RELAYER = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

    uint256 internal constant USDS_MINT_AMOUNT     = 9_000_000e18;
    uint256 internal constant SUSDS_DEPOSIT_AMOUNT = 8_000_000e18;
    uint256 internal constant USDS_BRIDGE_AMOUNT   = 1_000_000e18;

    address internal constant BASE_PAYLOAD = address(0);

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
        // Reduce LT from 70% to 65%
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](1);
        updates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WBTC,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   65_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });
        return updates;
    }

    function _postExecute() internal override {
        // --- Increase Morpho PT sUSDe Dec Supply Cap ---
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_26DEC2024,
                oracle:          PT_26DEC2024_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            200_000_000e18
        );

        // --- Adjust WETH Slope 1 Spread ---
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.WETH,
            WETH_IRM
        );

        // --- Adjust wstETH Borrow Rate Limits ---
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setBorrowCapConfig({
            asset:            Ethereum.WSTETH,
            max:              10_000,
            gap:              2_000,
            increaseCooldown: 12 hours
        });

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
        ITokenBridge(Ethereum.BASE_TOKEN_BRIDGE).bridgeERC20To(Ethereum.USDS,  Base.USDS,  Base.ALM_PROXY, USDS_BRIDGE_AMOUNT, 5_000_000, "");  // TODO can probably tighten this gas limit
        ITokenBridge(Ethereum.BASE_TOKEN_BRIDGE).bridgeERC20To(Ethereum.SUSDS, Base.SUSDS, Base.ALM_PROXY, susdsShares,        5_000_000, "");  // TODO can probably tighten this gas limit

        // --- Trigger Base Payload ---
        OptimismForwarder.sendMessageL1toL2({
            l1CrossDomain: OptimismForwarder.L1_CROSS_DOMAIN_BASE,
            target:        Base.SPARK_RECEIVER,
            message:       encodePayloadQueue(BASE_PAYLOAD),
            gasLimit:      5_000_000
        });
    }
    
}
