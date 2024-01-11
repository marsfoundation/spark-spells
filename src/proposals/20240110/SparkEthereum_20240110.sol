// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, EngineFlags } from '../../SparkPayloadEthereum.sol';

import { IACLManager }            from 'aave-v3-core/contracts/interfaces/IACLManager.sol';
import { IPool }                  from 'aave-v3-core/contracts/interfaces/IPool.sol';
import { IPoolAddressesProvider } from 'aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol';
import { DataTypes }              from 'aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';

import { IEACAggregatorProxy }   from "aave-v3-periphery/misc/interfaces/IEACAggregatorProxy.sol";
import { IEmissionManager }      from "aave-v3-periphery/rewards/interfaces/IEmissionManager.sol";
import { ITransferStrategyBase } from "aave-v3-periphery/rewards/interfaces/ITransferStrategyBase.sol";
import { RewardsDataTypes }      from "aave-v3-periphery/rewards/libraries/RewardsDataTypes.sol";

import { ISparkLendFreezerMom } from './ISparkLendFreezerMom.sol';

interface IIncentivizedERC20 {
    function getIncentivesController() external view returns (address);
    function setIncentivesController(address controller) external;
}

/**
 * @title  January 10, 2024 Spark Ethereum Proposal
 * @author Phoenix Labs
 * @dev    Activate Freezer Mom, DAI oracle to hardcoded $1, wstETH oracle assume 1:1 stETH peg, Freeze GNO, Activate Lido Rewards.
 * Forum:  https://forum.makerdao.com/t/spark-spell-proposed-changes/23298
 * Polls:  https://vote.makerdao.com/polling/QmeWioX1#poll-detail
 *         https://vote.makerdao.com/polling/QmdVy1Uk#poll-detail
 *         https://vote.makerdao.com/polling/QmXtvu32#poll-detail
 *         https://vote.makerdao.com/polling/QmRdew4b#poll-detail
 *         https://vote.makerdao.com/polling/QmRKkMnx#poll-detail
 *         https://vote.makerdao.com/polling/QmdQSuAc#poll-detail
 */
contract SparkEthereum_20240110 is SparkPayloadEthereum {

    address public constant ACL_MANAGER           = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address public constant AUTHORITY             = 0x0a3f6849f78076aefaDf113F5BED87720274dDC0;
    address public constant DAI                   = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant DAI_ORACLE            = 0x42a03F81dd8A1cEcD746dc262e4d1CD9fD39F777;
    address public constant EMISSION_MANAGER      = 0xf09e48dd4CA8e76F63a57ADd428bB06fee7932a4;
    address public constant FREEZER_MOM           = 0xFA36c12Bc307b40c701D65d8FE8F88cCEdE2277a;
    address public constant GNO                   = 0x6810e776880C02933D47DB1b9fc05908e5386b96;
    address public constant INCENTIVES_CONTROLLER = 0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    address public constant REWARDS_OPERATOR      = 0x8076807464DaC94Ac8Aa1f7aF31b58F73bD88A27;  // Operator multi-sig (also custodies the rewards)
    address public constant TRANSFER_STRATEGY     = 0x11aAC1cA5822cf8Ba6d06B0d84901940c0EE36d8;
    address public constant WETH                  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WETH_ATOKEN           = 0x59cD1C87501baa753d0B5B5Ab5D8416A45cD71DB;
    address public constant WSTETH                = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant WSTETH_ORACLE         = 0x8B6851156023f4f5A66F68BEA80851c3D905Ac93;
    address public constant POOL_ADDRESS_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    address public constant POOL_IMPLEMENTATION   = 0xB40f6d584081ac2b0FD84C846dBa3C1417889304;

    uint256 public constant DURATION      = 30 days;
    uint256 public constant REWARD_AMOUNT = 20 ether;

    function _preExecute() internal override {
        // Hot fix for Jan 10th issue
        IPoolAddressesProvider(POOL_ADDRESS_PROVIDER).setPoolImpl(POOL_IMPLEMENTATION);

        // --- Set Incentives Controller for all reserves ---
        IPool pool = LISTING_ENGINE.POOL();
        address[] memory reserves = pool.getReservesList();
        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveData memory reserveData = pool.getReserveData(reserves[i]);
            if (IIncentivizedERC20(reserveData.aTokenAddress).getIncentivesController() == address(0)) {
                IIncentivizedERC20(reserveData.aTokenAddress).setIncentivesController(INCENTIVES_CONTROLLER);
            }
            if (IIncentivizedERC20(reserveData.variableDebtTokenAddress).getIncentivesController() == address(0)) {
                IIncentivizedERC20(reserveData.variableDebtTokenAddress).setIncentivesController(INCENTIVES_CONTROLLER);
            }
            if (IIncentivizedERC20(reserveData.stableDebtTokenAddress).getIncentivesController() == address(0)) {
                IIncentivizedERC20(reserveData.stableDebtTokenAddress).setIncentivesController(INCENTIVES_CONTROLLER);
            }
        }
    }

    function priceFeedsUpdates() public pure override returns (IEngine.PriceFeedUpdate[] memory) {
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

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
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
        // --- Freeze GNO ---
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveFreeze(GNO, true);

        // --- Activate the Freezer Mom ---
        ISparkLendFreezerMom(FREEZER_MOM).setAuthority(AUTHORITY);
        IACLManager(ACL_MANAGER).addEmergencyAdmin(FREEZER_MOM);
        IACLManager(ACL_MANAGER).addRiskAdmin(FREEZER_MOM);

        // --- Activate Lido Rewards ---
        IEmissionManager(EMISSION_MANAGER).setEmissionAdmin(WSTETH, address(this));

        RewardsDataTypes.RewardsConfigInput[] memory rewardConfigs = new RewardsDataTypes.RewardsConfigInput[](1);

        rewardConfigs[0] = RewardsDataTypes.RewardsConfigInput({
            emissionPerSecond: uint88(REWARD_AMOUNT / DURATION),
            totalSupply:       0,  // Set by the rewards controller
            distributionEnd:   uint32(block.timestamp + DURATION),
            asset:             WETH_ATOKEN,  // Rewards on WETH supplies
            reward:            WSTETH,
            transferStrategy:  ITransferStrategyBase(TRANSFER_STRATEGY),
            rewardOracle:      IEACAggregatorProxy(WSTETH_ORACLE)
        });

        IEmissionManager(EMISSION_MANAGER).configureAssets(rewardConfigs);
        IEmissionManager(EMISSION_MANAGER).setEmissionAdmin(WSTETH, REWARDS_OPERATOR);
    }

}
