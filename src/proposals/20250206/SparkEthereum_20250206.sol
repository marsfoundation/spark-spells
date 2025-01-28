// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { Ethereum }                                   from 'spark-address-registry/Ethereum.sol';
import { SparkPayloadEthereum, IEngine, EngineFlags } from "../../SparkPayloadEthereum.sol";

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

    address public immutable wETH_PRICEFEED   = 0x2750e4CB635aF1FCCFB10C0eA54B5b5bfC2759b6;
    address public immutable cbBTC_PRICEFEED  = 0x4219aA1A99f3fe90C2ACB97fCbc1204f6485B537;

    constructor() {
        // TODO: set to Base address when deployed
        PAYLOAD_BASE = address(0);
    }

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](1);

        // Reduce LT from 55% to 50%
        updates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WBTC,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   50_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return updates;
    }

    function priceFeedsUpdates() public view override returns (IEngine.PriceFeedUpdate[] memory) {
        IEngine.PriceFeedUpdate[] memory updates = new IEngine.PriceFeedUpdate[](1);
        updates[0] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.WETH,
            priceFeed: wETH_PRICEFEED
        });
        return updates;
    }

    function _postExecute() internal override {
        _onboardERC4626Vault(
            FLUID_SUSDS_VAULT,
            FLUID_SUDS_MAX_DEPOSIT,
            FLUID_SUDS_MAX_SLOPE
        );
    }

}
