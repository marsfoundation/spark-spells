// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IMetaMorpho, MarketParams } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';
import { Gnosis }                    from 'lib/spark-address-registry/src/Gnosis.sol';
import { XChainForwarders }          from 'lib/xchain-helpers/src/XChainForwarders.sol';

import { SparkPayloadEthereum, Ethereum, IEngine, EngineFlags, Rates } from 'src/SparkPayloadEthereum.sol';


/**
 * @title  May 30, 2024 Spark Ethereum Proposal
 * @notice Turn off silo borrowing for USDC/USDC, update IRMs for USDC/USDT/ETH, update Morpho supply caps, trigger Gnosis Payload.
 * @author Phoenix Labs
 * Forum:  https://forum.makerdao.com/t/may-21-2024-proposed-changes-to-sparklend-for-upcoming-spell/24327
 * Votes:  TODO
 */
contract SparkEthereum_20240530 is SparkPayloadEthereum {

    address public constant STABLECOINS_IRM = 0x4Da18457A76C355B74F9e4A944EcC882aAc64043;
    
    address public constant GNOSIS_PAYLOAD = address(0);  // TODO

    function borrowsUpdates() public view override returns (IEngine.BorrowUpdate[] memory) {
        IEngine.BorrowUpdate[] memory borrowUpdates = new IEngine.BorrowUpdate[](2);

        borrowUpdates[0] = IEngine.BorrowUpdate({
            asset:                 Ethereum.USDC,
            enabledToBorrow:       EngineFlags.KEEP_CURRENT,
            flashloanable:         EngineFlags.KEEP_CURRENT,
            stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
            borrowableInIsolation: EngineFlags.KEEP_CURRENT,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            reserveFactor:         EngineFlags.KEEP_CURRENT
        });
        borrowUpdates[1] = IEngine.BorrowUpdate({
            asset:                 Ethereum.USDT,
            enabledToBorrow:       EngineFlags.KEEP_CURRENT,
            flashloanable:         EngineFlags.KEEP_CURRENT,
            stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
            borrowableInIsolation: EngineFlags.KEEP_CURRENT,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            reserveFactor:         EngineFlags.KEEP_CURRENT
        });

        return borrowUpdates;
    }

    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](1);

        Rates.RateStrategyParams memory wethParams = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(Ethereum.WETH);

        wethParams.variableRateSlope1 = _bpsToRay(2_50);

        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  Ethereum.WETH,
            params: wethParams
        });

        return ratesUpdate;
    }

    function _postExecute()
        internal override
    {
        // Set USDC/USDT IRM
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.USDC,
            STABLECOINS_IRM
        );
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.USDT,
            STABLECOINS_IRM
        );

        // Morpho Vault Supply Cap Changes
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: Ethereum.SUSDE,
                oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.86e18
            }),
            400_000_000e18
        );
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: Ethereum.SUSDE,
                oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            100_000_000e18
        );

        // Trigger Gnosis Payload
        XChainForwarders.sendMessageGnosis(
            Gnosis.AMB_EXECUTOR,
            encodePayloadQueue(GNOSIS_PAYLOAD),
            4_000_000
        );
    }

}
