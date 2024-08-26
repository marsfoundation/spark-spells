// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { Ethereum, SparkPayloadEthereum, IEngine, EngineFlags } from 'src/SparkPayloadEthereum.sol';
import { IKillSwitchOracle } from 'lib/sparklend-kill-switch/src/interfaces/IKillSwitchOracle.sol';
import {IV3RateStrategyFactory as Rates} from '../../interfaces/IV3RateStrategyFactory.sol';
import { IAaveOracle } from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";

struct AssetsConfig {
    address[] ids;
    Basic[] basics;
    Borrow[] borrows;
    Collateral[] collaterals;
    Caps[] caps;
    Rates.RateStrategyParams[] rates;
}

struct Basic {
    string assetSymbol;
    address priceFeed;
    Rates.RateStrategyParams rateStrategyParams;
    IEngine.TokenImplementations implementations;
}

struct Borrow {
    uint256 enabledToBorrow; // Main config flag, if EngineFlag.DISABLED, some of the other fields will not be considered
    uint256 flashloanable; // EngineFlag.ENABLED for true, EngineFlag.DISABLED for false otherwise EngineFlag.KEEP_CURRENT
    uint256 stableRateModeEnabled; // EngineFlag.ENABLED for true, EngineFlag.DISABLED for false otherwise EngineFlag.KEEP_CURRENT
    uint256 borrowableInIsolation; // EngineFlag.ENABLED for true, EngineFlag.DISABLED for false otherwise EngineFlag.KEEP_CURRENT
    uint256 withSiloedBorrowing; // EngineFlag.ENABLED for true, EngineFlag.DISABLED for false otherwise EngineFlag.KEEP_CURRENT
    uint256 reserveFactor; // With 2 digits precision, `10_00` for 10%. Should be positive and < 100_00
}

struct Collateral {
    uint256 ltv; // Only considered if liqThreshold > 0. With 2 digits precision, `10_00` for 10%. Should be lower than liquidationThreshold
    uint256 liqThreshold; // If `0`, the asset will not be enabled as collateral. Same format as ltv, and should be higher
    uint256 liqBonus; // Only considered if liqThreshold > 0. Same format as ltv
    uint256 debtCeiling; // Only considered if liqThreshold > 0. In USD and without decimals, so 100_000 for 100k USD debt ceiling
    uint256 liqProtocolFee; // Only considered if liqThreshold > 0. Same format as ltv
    uint256 eModeCategory;
}

struct Caps {
    uint256 supplyCap; // Always configured. In "big units" of the asset, and no decimals. 100 for 100 ETH supply cap
    uint256 borrowCap; // Always configured, no matter if enabled for borrowing or not. Same format as supply cap
}

/**
 * @title  Aug 23, 2024 Spark Ethereum Proposal
 * @notice Oracle Upgrade to ETH, wstETH, rETH and weETH markets to use Aggor
 *         Remove WBTC/BTC from kill switch
 * @author Wonderland
 * Forum:  https://forum.makerdao.com/t/aug-23-2024-proposal-changes-to-spark-for-upcoming-spell/24940
 * Vote:  TODO
 */
contract SparkEthereum_20240823 is SparkPayloadEthereum {

    address internal constant WETH_ORACLE = 0xf07ca0e66A798547E4CB3899EC592e1E99Ef6Cb3;
    address internal constant WSTETH_ORACLE = 0xf77e132799DBB0d83A4fB7df10DA04849340311A;
    address internal constant RETH_ORACLE = 0x11af58f13419fD3ce4d3A90372200c80Bc62f140;
    address internal constant WEETH_ORACLE = 0x28897036f8459bFBa886083dD6b4Ce4d2f14a57F;

    address internal constant WBTC_BTC_ORACLE  = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;

    IAaveOracle internal constant ORACLE = IAaveOracle(Ethereum.AAVE_ORACLE);
    
    function priceFeedsUpdates() public pure override returns (IEngine.PriceFeedUpdate[] memory) {
        IEngine.PriceFeedUpdate[] memory updates = new IEngine.PriceFeedUpdate[](3);

        updates[0] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.WSTETH,
            priceFeed: WSTETH_ORACLE
        });
        updates[1] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.RETH,
            priceFeed: RETH_ORACLE
        });
        updates[2] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.WEETH,
            priceFeed: WEETH_ORACLE
        });

        return updates;
    }

    function _postExecute()
        internal override
    {
        // Disable the kill switch for the WBTC-BTC oracle
        IKillSwitchOracle(Ethereum.KILL_SWITCH_ORACLE).disableOracle(WBTC_BTC_ORACLE);

        // Change the WETH oracle to the aggor one
        IEngine.PriceFeedUpdate[] memory updates = new IEngine.PriceFeedUpdate[](1);

        updates[0] = IEngine.PriceFeedUpdate({
            asset:     Ethereum.WETH,
            priceFeed: WETH_ORACLE
        });

        _updatePriceFeeds(updates);
    }

    // Taken from the spark config engine (0x3254F7cd0565aA67eEdC86c2fB608BE48d5cCd78)
    function _updatePriceFeeds(IEngine.PriceFeedUpdate[] memory updates) internal {
        require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

        AssetsConfig memory configs = _repackPriceFeed(updates);

        _setPriceFeeds(configs.ids, configs.basics);
    }

    // Taken from the spark config engine (0x3254F7cd0565aA67eEdC86c2fB608BE48d5cCd78)
    function _repackPriceFeed(IEngine.PriceFeedUpdate[] memory updates) internal pure returns (AssetsConfig memory) {
        address[] memory ids = new address[](updates.length);
        Basic[] memory basics = new Basic[](updates.length);

        for (uint256 i = 0; i < updates.length; i++) {
        ids[i] = updates[i].asset;
        basics[i] = Basic({
            priceFeed: updates[i].priceFeed,
            assetSymbol: string(''), // unused for price feed update
            rateStrategyParams: Rates.RateStrategyParams(0, 0, 0, 0, 0, 0, 0, 0, 0), // unused for price feed update
            implementations: IEngine.TokenImplementations(address(0), address(0), address(0)) // unused for price feed update
        });
        }

        return
        AssetsConfig({
            ids: ids,
            caps: new Caps[](0),
            basics: basics,
            borrows: new Borrow[](0),
            collaterals: new Collateral[](0),
            rates: new Rates.RateStrategyParams[](0)
        });
    }

    // Taken from the spark config engine (0x3254F7cd0565aA67eEdC86c2fB608BE48d5cCd78)
    function _setPriceFeeds(address[] memory ids, Basic[] memory basics) internal {
        address[] memory assets = new address[](ids.length);
        address[] memory sources = new address[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
        require(basics[i].priceFeed != address(0), 'PRICE_FEED_ALWAYS_REQUIRED');
        // Removed as it fails with the WETH oracle. It should only be called by the aave oracle
        // require(
        //     IChainlinkAggregator(basics[i].priceFeed).latestAnswer() > 0,
        //     'FEED_SHOULD_RETURN_POSITIVE_PRICE'
        // );
        assets[i] = ids[i];
        sources[i] = basics[i].priceFeed;
        }

        ORACLE.setAssetSources(assets, sources);
    }
}
