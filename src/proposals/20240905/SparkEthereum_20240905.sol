// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { Ethereum, SparkPayloadEthereum, IEngine } from 'src/SparkPayloadEthereum.sol';
import { IKillSwitchOracle } from 'lib/sparklend-kill-switch/src/interfaces/IKillSwitchOracle.sol';
import { IAaveOracle } from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";

/**
 * @title  Sep 09, 2024 Spark Ethereum Proposal
 * @notice Oracle Upgrade to ETH, wstETH, rETH and weETH markets to use Aggor
 *         Remove WBTC/BTC from kill switch
 * @author Wonderland
 * Forum:  https://forum.makerdao.com/t/aug-23-2024-proposal-changes-to-spark-for-upcoming-spell/24940
 * Vote:   https://vote.makerdao.com/polling/QmW55juU
 *         https://vote.makerdao.com/polling/QmQa73Cc
 */
contract SparkEthereum_20240905 is SparkPayloadEthereum {

    address internal constant WETH_ORACLE     =    0xf07ca0e66A798547E4CB3899EC592e1E99Ef6Cb3;
    address internal constant WSTETH_ORACLE   =    0xf77e132799DBB0d83A4fB7df10DA04849340311A;
    address internal constant RETH_ORACLE     =    0x11af58f13419fD3ce4d3A90372200c80Bc62f140;
    address internal constant WEETH_ORACLE    =    0x28897036f8459bFBa886083dD6b4Ce4d2f14a57F;

    address internal constant WBTC_BTC_ORACLE =    0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;
    
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
        address[] memory assets     =   new address[](1);
        address[] memory sources    =   new address[](1);

        assets[0]   =   Ethereum.WETH;
        sources[0]  =   WETH_ORACLE;

        IAaveOracle(Ethereum.AAVE_ORACLE).setAssetSources(assets, sources);
    }
}
