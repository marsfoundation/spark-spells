// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum }                        from 'spark-address-registry/Ethereum.sol';
import { RateLimitHelpers, RateLimitData } from "spark-alm-controller/src/RateLimitHelpers.sol";
import { MainnetController }               from 'spark-alm-controller/src/MainnetController.sol';

import { SparkPayloadEthereum } from "../../SparkPayloadEthereum.sol";

/**
 * @title  Jan 23, 2025 Spark Ethereum Proposal
 * @notice Sparklend: Onboard SUSDS
           Spark Liquidity Layer: Onboard Aave Prime USDS, Sparklend USDS and Sparklend USDC
 * @author Wonderland
 * Forum:  http://forum.sky.money/t/jan-23-2025-proposed-changes-to-spark-for-upcoming-spell/25825
 * Vote:   https://vote.makerdao.com/polling/QmRAavx5
 *         https://vote.makerdao.com/polling/QmY4D1u8
 *         https://vote.makerdao.com/polling/QmU3Xu4W
 */
contract SparkEthereum_20250123 is SparkPayloadEthereum {
    address constant public AAVE_PRIME_USDS_ATOKEN = 0x09AA30b182488f769a9824F15E6Ce58591Da4781;
    address constant public SPARKLEND_USDC_ATOKEN  = 0x377C3bd93f2a2984E1E7bE6A5C22c525eD4A4815;

    MainnetController controller = MainnetController(Ethereum.ALM_CONTROLLER);

    function _postExecute() internal override {
        _onboardAaveToken(
            SPARKLEND_USDC_ATOKEN,
            20_000_000e6,
            uint256(10_000_000e6) / 1 days
        );
        _onboardAaveToken(
            AAVE_PRIME_USDS_ATOKEN,
            50_000_000e18,
            uint256(50_000_000e18) / 1 days
        );
    }

}
