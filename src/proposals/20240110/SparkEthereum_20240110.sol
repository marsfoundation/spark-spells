// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, EngineFlags } from '../../SparkPayloadEthereum.sol';

import { IACLManager } from 'aave-v3-core/contracts/interfaces/IACLManager.sol';

import { IEmissionManager }   from "aave-v3-periphery/rewards/interfaces/IEmissionManager.sol";
import { IRewardsController } from "aave-v3-periphery/rewards/interfaces/IRewardsController.sol";
import { RewardsDataTypes }   from "aave-v3-periphery/rewards/libraries/RewardsDataTypes.sol";

import { ISparkLendFreezerMom } from './ISparkLendFreezerMom.sol';

/**
 * @title  January 10, 2024 Spark Ethereum Proposal
 * @author Phoenix Labs
 * @dev    Activate Freezer Mom, DAI oracle to hardcoded $1, wstETH oracle assume 1:1 stETH peg, Freeze GNO, Activate Lido Rewards.
 * Forum:  https://forum.makerdao.com/t/spark-spell-proposed-changes/23298
 * Polls:  TODO
 */
contract SparkEthereum_20240110 is SparkPayloadEthereum {

    address constant FREEZER_MOM        = ;  // TODO deploy
    address constant AUTHORITY          = 0x0a3f6849f78076aefaDf113F5BED87720274dDC0;
    address constant ACL_MANAGER        = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address constant DAI                = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant DAI_ORACLE         = ;  // TODO deploy
    address constant WSTETH             = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant WSTETH_ORACLE      = 0x8B6851156023f4f5A66F68BEA80851c3D905Ac93;
    address constant GNO                = 0x6810e776880C02933D47DB1b9fc05908e5386b96;
    address constant WETH               = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WETH_ATOKEN        = 0x59cD1C87501baa753d0B5B5Ab5D8416A45cD71DB;
    address constant TRANSFER_STRATEGY  = ;  // TODO deploy
    address constant EMISSION_MANAGER   = 0xf09e48dd4CA8e76F63a57ADd428bB06fee7932a4;
    address constant REWARDS_OPERATOR   = 0x8076807464DaC94Ac8Aa1f7aF31b58F73bD88A27;  // Operator multi-sig (also custodies the rewards)
    uint256 constant REWARD_AMOUNT      = 20 ether;
    uint256 constant DURATION           = 30 days;

    function priceFeedsUpdates() public view override returns (IEngine.PriceFeedUpdate[] memory) {
        IEngine.PriceFeedUpdate[] memory updates = new IEngine.PriceFeedUpdate[](2);

        updates[0] = IEngine.PriceFeedUpdate({
            asset:     DAI,
            priceFeed: DAI_ORACLE
        });
        updates[1] = IEngine.PriceFeedUpdate({
            asset:     WSTETH,
            priceFeed: WSTETH_ORACLE
        });

        return updates;
    }

    function collateralsUpdates() public view override returns (IEngine.CollateralUpdate[] memory) {
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](1);

        updates[0] = IEngine.CollateralUpdate({
            asset:          GNO,
            ltv:            0,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return updates;
    }

    function _postExecute() internal override {
        // --- Activate the Freezer Mom ---
        ISparkLendFreezerMom freezerMom = ISparkLendFreezerMom(FREEZER_MOM);

        require(freezerMom.pool()             == LISTING_ENGINE.POOL(),              "pool mismatch");
        require(freezerMom.poolConfigurator() == LISTING_ENGINE.POOL_CONFIGURATOR(), "poolConfigurator mismatch");

        freezerMom.setAuthority(AUTHORITY);
        IACLManager(ACL_MANAGER).addEmergencyAdmin(address(freezerMom));
        IACLManager(ACL_MANAGER).addRiskAdmin(address(freezerMom));

        // --- Activate Lido Rewards ---
        IEmissionManager(EMISSION_MANAGER).setEmissionAdmin(WSTETH, REWARDS_OPERATOR);

        RewardsDataTypes.RewardsConfigInput[] memory rewardConfigs = new RewardsDataTypes.RewardsConfigInput[](1);

        configs[0] = RewardsDataTypes.RewardsConfigInput({
            emissionPerSecond: uint88(REWARD_AMOUNT / DURATION),
            totalSupply:       0,  // Set by the rewards controller
            distributionEnd:   uint32(block.timestamp + DURATION),
            asset:             WETH_ATOKEN,  // Rewards on WETH supplies
            reward:            WSTETH,
            transferStrategy:  TRANSFER_STRATEGY,
            rewardOracle:      WSTETH_ORACLE
        });

        IEmissionManager(EMISSION_MANAGER).configureAssets(configs);
    }

}
