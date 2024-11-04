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
 * @title  Nov 14, 2024 Spark Base Proposal
 * @notice Activate Spark Liquidity Layer
 * @author Phoenix Labs
 * Forum:  https://forum.sky.money/t/14-nov-2024-proposed-changes-to-spark-for-upcoming-spell/25466
 * Vote:   https://vote.makerdao.com/polling/Qmf955yA
 */
contract SparkBase_20241114 is SparkPayloadBase {

    address internal constant FREEZER = 0x90D8c80C028B4C09C0d8dcAab9bbB057F0513431;  // Gov. facilitator multisig
    address internal constant RELAYER = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

    function execute() external {
        // --- Activate Mainnet Controller ---
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
                usdcDepositData          : RateLimitData({
                    maxAmount : 4_000_000e6,
                    slope     : 2_000_000e6 / uint256(1 days)
                }),
                usdcWithdrawData         : RateLimitData({
                    maxAmount : 7_000_000e6,
                    slope     : 2_000_000e6 / uint256(1 days)
                }),
                usdsDepositData          : RateLimitData({
                    maxAmount : 5_000_000e18,
                    slope     : 2_000_000e18 / uint256(1 days)
                }),
                usdsWithdrawData         : unlimitedRateLimit,
                susdsDepositData         : RateLimitData({
                    maxAmount : 8_000_000e18,
                    slope     : 2_000_000e18 / uint256(1 days)
                }),
                susdsWithdrawData        : unlimitedRateLimit,
                usdcToCctpData           : unlimitedRateLimit,
                cctpToEthereumDomainData : RateLimitData({
                    maxAmount : 4_000_000e6,
                    slope     : 2_000_000e6 / uint256(1 days)
                })
            }),
            mintRecipients: mintRecipients
        });
    }
}
