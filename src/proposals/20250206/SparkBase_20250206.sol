// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IMetaMorpho }      from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';
import { Base }             from 'spark-address-registry/Base.sol';
import { SparkPayloadBase } from "../../SparkPayloadBase.sol";

/**
 * @title  Feb 06, 2025 Spark Base Proposal
 * @notice Spark Liquidity Layer: onboard Fluid sUSDS, increase Morpho Vault Timelock
 * @author Wonderland
 * Forum:  TODO
 * Vote:   TODO - increase Morpho Vault Timelock
 *         TODO - onboard Fluid sUSDS
 */
contract SparkBase_20250206 is SparkPayloadBase {

    address public immutable FLUID_SUSDS_VAULT      = 0xf62e339f21d8018940f188F6987Bcdf02A849619;
    uint256 public immutable FLUID_SUDS_MAX_DEPOSIT = 50_000_000e18;
    uint256 public immutable FLUID_SUDS_MAX_SLOPE   = 50_000_000e18 / uint256(1 days);

    uint256 public immutable NEW_TIMELOCK = 1 days;

    function execute() external { 
        _onboardERC4626Vault(
            FLUID_SUSDS_VAULT,
            FLUID_SUDS_MAX_DEPOSIT,
            FLUID_SUDS_MAX_SLOPE
        );
        IMetaMorpho(Base.MORPHO_VAULT_SUSDC).submitTimelock(NEW_TIMELOCK);
    }

}
