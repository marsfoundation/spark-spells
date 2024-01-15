// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, IEngine, Rates, EngineFlags, Address } from '../../SparkPayloadEthereum.sol';

/**
 * @title  January 24, 2024 Spark Ethereum Proposal - Raise WBTC supply cap
 * @author Phoenix Labs
 * @dev This proposal sets WBTC supplyCap
 * Forum:     TBA
 * WBTC Vote: TBA
 */
contract SparkEthereum_20241024 is SparkPayloadEthereum {

    using Address for address;

    address public constant FIXED_PRICE_ORACLE = 0x42a03F81dd8A1cEcD746dc262e4d1CD9fD39F777;
    address public constant USDC               = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT               = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WBTC               = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;


    function priceFeedsUpdates() public pure override returns (IEngine.PriceFeedUpdate[] memory) {
        IEngine.PriceFeedUpdate[] memory updates = new IEngine.PriceFeedUpdate[](2);

        updates[0] = IEngine.PriceFeedUpdate({
            asset:     USDC,
            priceFeed: FIXED_PRICE_ORACLE
        });
        updates[1] = IEngine.PriceFeedUpdate({
            asset:     USDT,
            priceFeed: FIXED_PRICE_ORACLE
        });

        return updates;
    }

    function capsUpdates()
        public pure override returns (IEngine.CapsUpdate[] memory)
    {
        IEngine.CapsUpdate[] memory capsUpdate = new IEngine.CapsUpdate[](1);
        capsUpdate[0] = IEngine.CapsUpdate({
            asset:     WBTC,
            supplyCap: 5_000,
            borrowCap: EngineFlags.KEEP_CURRENT
        });

        return capsUpdate;
    }

}
