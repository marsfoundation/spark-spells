// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { Ethereum, SparkPayloadEthereum, IEngine, EngineFlags } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  Aug 08, 2024 Spark Ethereum Proposal
 * @notice Activate Lido LST Interest Rate Model (IRM), Decrease DAI Borrow Rate, WBTC Risk Mitigation
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/jul-27-2024-proposed-changes-to-spark-for-upcoming-spell/24755
 *         https://forum.makerdao.com/t/stability-scope-parameter-changes-15-sfs-dsr-spark-effective-dai-borrow-rate-reduction/24834
 *         https://forum.makerdao.com/t/wbtc-changes-and-risk-mitigation-10-august-2024/24844
 * Vote:   https://vote.makerdao.com/polling/QmdFCRfK
 */
contract SparkEthereum_20240808 is SparkPayloadEthereum {

    // Per-second APY for DSR comes from: https://github.com/makerdao/spells-mainnet/blob/master/src/test/rates.sol
    // Formula for 6% target DSR APY (0.058268908177807359323232000)
    // bc -l <<< 'scale=27; (1.000000001847694957439350562 - 1) * 60 * 60 * 24 * 365'
    // Formula for 7% target APY (0.009389740368586287841344000 spread at current DSR):
    // bc -l <<< 'scale=27; (e( l(1.07)/(60 * 60 * 24 * 365) ) - 1) * 60 * 60 * 24 * 365 - 0.058268908177807359323232000'
    address internal constant DAI_IRM  = 0xC527A1B514796A6519f236dd906E73cab5aA2E71;
    address internal constant WETH_IRM = 0x6fd32465a23aa0DBaE0D813B7157D8CB2b08Dae4;

    function collateralsUpdates() public view override returns (IEngine.CollateralUpdate[] memory) {
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](1);
        updates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WBTC,
            ltv:            0,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });
        return updates;
    }

    function borrowsUpdates() public view override returns (IEngine.BorrowUpdate[] memory) {
        IEngine.BorrowUpdate[] memory updates = new IEngine.BorrowUpdate[](1);
        updates[0] = IEngine.BorrowUpdate({
            asset:                 Ethereum.WBTC,
            enabledToBorrow:       EngineFlags.DISABLED,
            flashloanable:         EngineFlags.KEEP_CURRENT,
            stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
            borrowableInIsolation: EngineFlags.KEEP_CURRENT,
            withSiloedBorrowing:   EngineFlags.KEEP_CURRENT,
            reserveFactor:         EngineFlags.KEEP_CURRENT
        });
        return updates;
    }

    function _postExecute()
        internal override
    {
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.DAI,
            DAI_IRM
        );
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.WETH,
            WETH_IRM
        );
    }
}
