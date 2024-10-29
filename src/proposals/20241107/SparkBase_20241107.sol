// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { Base, SparkPayloadBase } from 'src/SparkPayloadBase.sol';

import { Ethereum } from 'spark-address-registry/Ethereum.sol';

import { CCTPForwarder } from 'xchain-helpers/forwarders/CCTPForwarder.sol';

import {
    ControllerInstance,
    ForeignControllerInit,
    RateLimitData,
    MintRecipient
} from 'lib/spark-alm-controller/deploy/ControllerInit.sol';

/**
 * @title  Nov 7, 2024 Spark Base Proposal
 * @notice Activate Spark Liquidity Layer
 * @author Phoenix Labs
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkBase_20241107 is SparkPayloadBase {

    address constant FREEZER = 0x90D8c80C028B4C09C0d8dcAab9bbB057F0513431;  // Gov. facilitator multisig
    address constant RELAYER = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

    function execute() external {
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
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(Ethereum.ALM_PROXY)))
        });

        ForeignControllerInit.init({
            addresses: ForeignControllerInit.AddressParams({
                admin         : Base.SPARK_EXECUTOR,
                freezer       : FREEZER,
                relayer       : RELAYER,
                oldController : address(0),
                psm           : Base.PSM3,
                cctpMessenger : Base.CCTP_TOKEN_MESSENGER,
                usdc          : Base.USDC,
                usds          : Base.USDS,
                susds         : Base.SUSDS
            }),
            controllerInst: ControllerInstance({
                almProxy   : Base.ALM_PROXY,
                controller : Base.ALM_CONTROLLER,
                rateLimits : Base.ALM_RATE_LIMITS
            }),
            data: ForeignControllerInit.InitRateLimitData({
                usdcDepositData          : rateLimitData6,
                usdcWithdrawData         : rateLimitData6,
                usdsDepositData          : rateLimitData18,
                usdsWithdrawData         : rateLimitData18,
                susdsDepositData         : rateLimitData18,
                susdsWithdrawData        : rateLimitData18,
                usdcToCctpData           : unlimitedRateLimit,
                cctpToEthereumDomainData : rateLimitData6
            }),
            mintRecipients: mintRecipients
        });
    }
}
