// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { IKillSwitchOracle } from 'lib/sparklend-kill-switch/src/interfaces/IKillSwitchOracle.sol';

interface IOracle {
    function latestAnswer() external view returns (int256);
}

contract SparkEthereum_20240823Test is SparkEthereumTestBase {

    address internal constant WETH_ORACLE_OLD =   0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal constant WSTETH_ORACLE_OLD = 0x8B6851156023f4f5A66F68BEA80851c3D905Ac93;
    address internal constant RETH_ORACLE_OLD =   0x05225Cd708bCa9253789C1374e4337a019e99D56;
    address internal constant WEETH_ORACLE_OLD =  0x1A6BDB22b9d7a454D20EAf12DB55D6B5F058183D;

    address internal constant WETH_ORACLE = 0xf07ca0e66A798547E4CB3899EC592e1E99Ef6Cb3;
    address internal constant WSTETH_ORACLE = 0x73CB2C1E77a2A17209e5f9829A22479bbefb3BFc;
    address internal constant RETH_ORACLE = 0x7D35cd22fBF9Bbfc5ebD54e124519Bb664D5681d;
    address internal constant WEETH_ORACLE = 0xb82a6B4006c94B57d30b6046dD68f108bffd7D41;

    address internal constant WBTC_BTC_ORACLE  = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;

    constructor() {
        id = '20240823';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20594398);  // Aug 23, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function test_validateOracles() public {
        vm.startPrank(0x8105f69D9C41644c6A0803fDA7D03Aa70996cFD9);
        // Less than 1% difference between the old and new oracles
        assertApproxEqRel(IOracle(WETH_ORACLE_OLD).latestAnswer(),   IOracle(WETH_ORACLE).latestAnswer(),   0.01e18);
        assertApproxEqRel(IOracle(WSTETH_ORACLE_OLD).latestAnswer(), IOracle(WSTETH_ORACLE).latestAnswer(), 0.01e18);
        assertApproxEqRel(IOracle(RETH_ORACLE_OLD).latestAnswer(),   IOracle(RETH_ORACLE).latestAnswer(),   0.01e18);
        assertApproxEqRel(IOracle(WEETH_ORACLE_OLD).latestAnswer(),  IOracle(WEETH_ORACLE).latestAnswer(),  0.01e18);
        vm.stopPrank();
    }

    function test_marketConfigChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WETH,   WETH_ORACLE_OLD);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WSTETH, WSTETH_ORACLE_OLD);
        // _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.RETH,   RETH_ORACLE_OLD); // The RETH oracle does not have a decimals function
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WEETH,  WEETH_ORACLE_OLD);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WETH,   WETH_ORACLE);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WSTETH, WSTETH_ORACLE);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.RETH,   RETH_ORACLE);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WEETH,  WEETH_ORACLE);
    }

    function test_disableKillSwitchOracle() public {
        IKillSwitchOracle killSwitchOracle = IKillSwitchOracle(Ethereum.KILL_SWITCH_ORACLE);
        assertEq(killSwitchOracle.hasOracle(WBTC_BTC_ORACLE), true);
        executePayload(payload);
        assertEq(killSwitchOracle.hasOracle(WBTC_BTC_ORACLE), false);
    }

}
