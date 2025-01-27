// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { SparkPayloadEthereum } from "../../SparkPayloadEthereum.sol";

/**
 * @title  Feb 06, 2025 Spark Ethereum Proposal
 * @notice Spark Liquidity Layer: Onboard Fluid sUSDS
 * @author Wonderland
 * Forum:  https://forum.sky.money/t/feb-6-2025-proposed-changes-to-spark-for-upcoming-spell-actual/25888
 * Vote:   TODO
 */
contract SparkEthereum_20250206 is SparkPayloadEthereum {
    address public immutable FLUID_SUSDS_VAULT      = 0x2BBE31d63E6813E3AC858C04dae43FB2a72B0D11;
    uint256 public immutable FLUID_SUDS_MAX_DEPOSIT = 10_000_000e18;
    uint256 public immutable FLUID_SUDS_MAX_SLOPE   = 5_000_000e18 / uint256(1 days);

    constructor() {
        // TODO: set to Base address when deployed
        PAYLOAD_BASE = address(0);
    }

    function _postExecute() internal override {
        _onboardERC4626Vault(
            FLUID_SUSDS_VAULT,
            FLUID_SUDS_MAX_DEPOSIT,
            FLUID_SUDS_MAX_SLOPE
        );
    }

}
