// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { SparkPayloadBase, Base } from "src/SparkPayloadBase.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { IMetaMorpho }  from "metamorpho/interfaces/IMetaMorpho.sol";
import { MarketParams } from "morpho-blue/src/interfaces/IMorpho.sol";

import { ControllerInstance }    from "spark-alm-controller/deploy/ControllerInstance.sol";
import { ForeignControllerInit } from "spark-alm-controller/deploy/ForeignControllerInit.sol";

/**
 * @title  Jan 9, 2025 Spark Base Proposal
 * @notice Onboard Aave aUSDC and Morpho USDC Vault
 * @author Phoenix Labs
 * Forum:  https://forum.sky.money/t/27-dec-2024-proposed-changes-to-spark-for-upcoming-spell/25760
 * Vote:   TODO
 */
contract SparkBase_20250109 is SparkPayloadBase {

    address internal constant NEW_ALM_CONTROLLER = 0xbE67325938Bf223a31Da7ff91777feD784F8163c;

    address internal constant ATOKEN_USDC = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB;

    address internal constant MORPHO_SPARK_USDC = 0x305E03Ed9ADaAB22F4A58c24515D79f2B1E2FD5D;

    address internal constant CBBTC              = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant CBBTC_USDC_ORACLE  = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address internal constant MORPHO_DEFAULT_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    function execute() external {
        // --- Spark Liquidity Layer Controller Upgrade ---

        _upgradeController();

        // --- Spark Liquidity Layer Onboarding ---

        // Aave V3
        _onboardAaveToken(ATOKEN_USDC, 20_000_000e18, 2_000_000e18 / uint256(1 days));

        // Morpho
        _activateMorphoVault(MORPHO_SPARK_USDC, false);
        _onboardERC4626Vault(MORPHO_SPARK_USDC, 20_000_000e18, 2_000_000e18 / uint256(1 days));

        // Onboard cbBTC/USDC 0 -> 100m
        IMetaMorpho(MORPHO_SPARK_USDC).submitCap(
            MarketParams({
                loanToken:       Base.USDC,
                collateralToken: CBBTC,
                oracle:          CBBTC_USDC_ORACLE,
                irm:             MORPHO_DEFAULT_IRM,
                lltv:            0.86e18
            }),
            // TODO check if this needs to be 6 decimals or 18
            100_000_000e18
        );
    }

    function _upgradeController() private {
        ForeignControllerInit.MintRecipient[] memory mintRecipients = new ForeignControllerInit.MintRecipient[](1);
        mintRecipients[0] = ForeignControllerInit.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(Ethereum.ALM_PROXY)))
        });

        ForeignControllerInit.upgradeController({
            controllerInst: ControllerInstance({
                almProxy   : Base.ALM_PROXY,
                controller : NEW_ALM_CONTROLLER,
                rateLimits : Base.ALM_RATE_LIMITS
            }),
            configAddresses: ForeignControllerInit.ConfigAddressParams({
                freezer       : Base.ALM_FREEZER,
                relayer       : Base.ALM_RELAYER,
                oldController : Base.ALM_CONTROLLER
            }),
            checkAddresses: ForeignControllerInit.CheckAddressParams({
                admin : Base.SPARK_PROXY,
                psm   : Base.PSM,
                cctp  : Base.CCTP_TOKEN_MESSENGER,
                usdc  : Base.USDC,
                susds : Base.SUSDS,
                usds  : Base.USDS
            }),
            mintRecipients: mintRecipients
        });
    }

}
