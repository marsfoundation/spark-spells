// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { Ethereum, SparkPayloadEthereum, IEngine, EngineFlags } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  Aug 23, 2024 Spark Ethereum Proposal
 * @notice Oracle Upgrade to ETH, wstETH, rETH and weETH markets to use Aggor
 *         Remove WBTC/BTC from kill switch
 * @author Wonderland
 * Forum:  https://forum.makerdao.com/t/aug-23-2024-proposal-changes-to-spark-for-upcoming-spell/24940
 * Vote:  TODO
 */
contract SparkEthereum_20240823 is SparkPayloadEthereum {

    address public constant WETH_ORACLE = 0xf07ca0e66A798547E4CB3899EC592e1E99Ef6Cb3;
    address public constant WSTETH_ORACLE = 0x73CB2C1E77a2A17209e5f9829A22479bbefb3BFc;
    address public constant RETH_ORACLE = 0x7D35cd22fBF9Bbfc5ebD54e124519Bb664D5681d;
    address public constant WEETH_ORACLE = 0xb82a6B4006c94B57d30b6046dD68f108bffd7D41;

    function priceFeedsUpdates() public pure override returns (IEngine.PriceFeedUpdate[] memory) {
        IEngine.PriceFeedUpdate[] memory updates = new IEngine.PriceFeedUpdate[](4);

        updates[0] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.WETH,
            priceFeed: WETH_ORACLE
        });
        updates[1] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.WSTETH,
            priceFeed: WSTETH_ORACLE
        });
        updates[2] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.RETH,
            priceFeed: RETH_ORACLE
        });
        updates[3] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.WEETH,
            priceFeed: WEETH_ORACLE
        });

        return updates;
    }

    // function _postExecute()
    //     internal override
    // {
    // }
}
