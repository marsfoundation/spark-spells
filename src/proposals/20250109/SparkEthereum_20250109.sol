// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum, SparkPayloadEthereum, IEngine, EngineFlags } from './SparkPayloadEthereum.sol';

import { IERC20 } from 'forge-std/interfaces/IERC20.sol';

import { Base } from 'spark-address-registry/Base.sol';

import { IMetaMorpho, MarketParams } from 'metamorpho/interfaces/IMetaMorpho.sol';

import { AllocatorBuffer } from 'dss-allocator/src/AllocatorBuffer.sol';
import { AllocatorVault }  from 'dss-allocator/src/AllocatorVault.sol';

import { OptimismForwarder } from 'xchain-helpers/forwarders/OptimismForwarder.sol';

import { MainnetControllerInit } from 'spark-alm-controller/deploy/MainnetControllerInit.sol';

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
 * @title  Jan 09, 2025 Spark Ethereum Proposal
 * @notice Sparklend: update WBTC, cbBTC, wstETH, weETH, DAI, USDC and USDT parameters
 *         Morpho: onboard PT-USDe-29May2025 and adjust existing caps
           Spark Liquidity Layer: Controller Upgrade, Onboard Ethena Direct,
                                  Aave V3 and increase liquidity available to Base
 * @author Phoenix Labs
 * Forum:  https://forum.sky.money/t/27-dec-2024-proposed-changes-to-spark-for-upcoming-spell/25760
 * Vote:   TODO
 */
contract SparkEthereum_20250109 is SparkPayloadEthereum {

    address internal constant NEW_ALM_CONTROLLER = address(0);

    address internal constant PT_SUSDE_24OCT2024_PRICE_FEED = 0xaE4750d0813B5E37A51f7629beedd72AF1f9cA35;
    address internal constant PT_SUSDE_24OCT2024            = 0xAE5099C39f023C91d3dd55244CAFB36225B0850E;
    address internal constant PT_SUSDE_26DEC2024_PRICE_FEED = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address internal constant PT_SUSDE_26DEC2024            = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;
    address internal constant PT_SUSDE_27MAR2025_PRICE_FEED = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address internal constant PT_SUSDE_27MAR2025            = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;
    address internal constant PT_SUSDE_29MAY2025_PRICE_FEED = 0xE84f7e0a890e5e57d0beEa2c8716dDf0c9846B4A;
    address internal constant PT_SUSDE_29MAY2025            = 0xb7de5dFCb74d25c2f21841fbd6230355C50d9308;

    address internal constant ATOKEN_USDS = 0x32a6268f9Ba3642Dda7892aDd74f1D34469A4259;
    address internal constant ATOKEN_USDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    uint256 internal constant USDS_MINT_AMOUNT = 100_000_000e18;

    address internal constant BASE_PAYLOAD = address(0);

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](2);

        // WBTC: Reduce LT from 65% to 60%
        updates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WBTC,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   55_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        // TODO cbBTC: possible LT/LTV adjustment

        updates[1] = IEngine.CollateralUpdate({
            asset:          Ethereum.WEETH,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    0,  // Disable isolation mode
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return updates;
    }

    function rateStrategiesUpdates()
        public
        pure
        override
        returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory updates = new IEngine.RateStrategyUpdate[](1);

        // TODO wstETH: possible IRM changes

        return updates;
    }

    function _postExecute() internal override {
        // --- Cap Automator Updates ---

        // TODO cbBTC: supply cap max, borrow and supply gap
        // TODO wstETH: supply cap max
        // TODO weETH: raise gap

        // --- Custom IRM Updates ---

        // TODO DAI, USDC, USDT: update IRM to anchor to SSR

        // --- Morpho Supply Cap Updates ---

        // TODO Reduce existing cap for PT-sUSDe-24Oct2024 100m -> 0
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_24OCT2024,
                oracle:          PT_SUSDE_24OCT2024_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.86e18
            }),
            0
        );


        // TODO Reduce existing cap for PT-sUSDe-26Dec2024 250m -> 0
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_26DEC2024,
                oracle:          PT_SUSDE_26DEC2024_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            0
        );

        // TODO Increase existing cap for PT-sUSDe-27Mar2025 400m -> X
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_27MAR2025,
                oracle:          PT_SUSDE_27MAR2025_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            600_000_000e18
        );

        // TODO Onboard PT-sUSDe-29May2025 0 -> X
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_29MAY2025,
                oracle:          PT_SUSDE_29MAY2025_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            200_000_000e18
        );

        // --- Spark Liquidity Layer Controller Upgrade ---

        _upgradeController();

        // --- Spark Liquidity Layer Onboarding ---

        // Ethena Direct
        _onboardEthena();

        // Aave V3
        _onboardAaveToken(ATOKEN_USDS, 20_000_000e18, 2_000_000e18 / uint256(1 days));
        _onboardAaveToken(ATOKEN_USDC, 20_000_000e6,  2_000_000e6 / uint256(1 days));

        // --- Send USDS and sUSDS to Base ---

        // Mint USDS
        AllocatorVault(Ethereum.ALLOCATOR_VAULT).draw(USDS_MINT_AMOUNT);
        AllocatorBuffer(Ethereum.ALLOCATOR_BUFFER).approve(Ethereum.USDS, address(this), USDS_MINT_AMOUNT);
        IERC20(Ethereum.USDS).transferFrom(Ethereum.ALLOCATOR_BUFFER, address(this), USDS_MINT_AMOUNT);

        // Bridge to Base
        IERC20(Ethereum.USDS).approve(Ethereum.BASE_TOKEN_BRIDGE, USDS_MINT_AMOUNT);
        ITokenBridge(Ethereum.BASE_TOKEN_BRIDGE).bridgeERC20To(Ethereum.USDS, Base.USDS, Base.ALM_PROXY, USDS_MINT_AMOUNT, 1_000_000, "");

        // --- Trigger Base Payload ---

        OptimismForwarder.sendMessageL1toL2({
            l1CrossDomain: OptimismForwarder.L1_CROSS_DOMAIN_BASE,
            target:        Base.SPARK_RECEIVER,
            message:       _encodePayloadQueue(BASE_PAYLOAD),
            gasLimit:      1_000_000
        });
    }

    function _upgradeController() private {
        MintRecipient[] memory mintRecipients = new MintRecipient[](1);
        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(Base.ALM_PROXY)))
        });

        MainnetControllerInit.upgradeController({
            controllerInst: ControllerInstance({
                almProxy   : Ethereum.ALM_PROXY,
                controller : NEW_ALM_CONTROLLER,
                rateLimits : Ethereum.ALM_RATE_LIMITS
            }),
            configAddresses: MainnetControllerInit.ConfigAddressParams({
                freezer       : FREEZER,
                relayer       : RELAYER,
                oldController : Ethereum.ALM_CONTROLLER
            }),
            checkAddresses: MainnetControllerInit.CheckAddressParams({
                admin      : Ethereum.SPARK_PROXY,
                proxy      : Ethereum.ALM_PROXY,
                rateLimits : Ethereum.ALM_RATE_LIMITS,
                vault      : Ethereum.ALLOCATOR_VAULT,
                psm        : Ethereum.PSM,
                daiUsds    : Ethereum.DAI_USDS,
                cctp       : Ethereum.CCTP_TOKEN_MESSENGER
            }),
            mintRecipients: mintRecipients
        });
    }

    function _onboardEthena() private {
        // TODO limits

        // USDe mint/burn
        MainnetControllerInit.setRateLimitData(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDE_MINT(),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 10_000_000e6,
                slope     : 2_000_000e6 / uint256(1 days)
            }),
            "ethenaMintLimit",
            6
        );
        MainnetControllerInit.setRateLimitData(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_USDE_MINT(),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 10_000_000e18,
                slope     : 2_000_000e18 / uint256(1 days)
            }),
            "ethenaBurnLimit",
            18
        );

        // sUSDe deposit (no need for withdrawal because of cooldown)
        MainnetControllerInit.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_4626_DEPOSIT(),
                Ethereum.SUSDE
            ),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 100_000_000e18,
                slope     : 50_000_000e6 / uint256(1 days)
            }),
            "susdeDepositLimit",
            18
        );

        // Cooldown
        MainnetControllerInit.setRateLimitData(
            MainnetController(Ethereum.ALM_CONTROLLER).LIMIT_SUSDE_COOLDOWN(),
            Ethereum.ALM_RATE_LIMITS,
            RateLimitData({
                maxAmount : 100_000_000e18,
                slope     : 50_000_000e18 / uint256(1 days)
            }),
            "susdeCooldownLimit",
            18
        );
    }

}
