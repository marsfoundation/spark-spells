// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IKillSwitchOracle } from '../../interfaces/IKillSwitchOracle.sol';

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
}

contract SparkEthereum_20240403Test is SparkEthereumTestBase {

    address internal constant KILL_SWITCH_ORACLE = 0x909A86f78e1cdEd68F9c2Fe2c9CD922c401abe82;

    address internal constant WBTC_BTC_ORACLE  = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;
    address internal constant STETH_ETH_ORACLE = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;

    constructor() {
        id = '20240403';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19523087);  // March 27, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testKillSwitchActivation() public {
        IKillSwitchOracle kso = IKillSwitchOracle(KILL_SWITCH_ORACLE);

        assertEq(kso.numOracles(), 0);
        assertEq(kso.oracleThresholds(WBTC_BTC_ORACLE),  0);
        assertEq(kso.oracleThresholds(STETH_ETH_ORACLE), 0);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(kso.numOracles(), 2);
        assertEq(kso.oracleThresholds(WBTC_BTC_ORACLE),  0.95e8);
        assertEq(kso.oracleThresholds(STETH_ETH_ORACLE), 0.95e18);
        
        // Sanity check the latest answers
        assertEq(IChainlinkAggregator(WBTC_BTC_ORACLE).latestAnswer(),  0.99897716e8);
        assertEq(IChainlinkAggregator(STETH_ETH_ORACLE).latestAnswer(), 0.999478607275791200e18);

        // Should not be able to trigger either
        assertEq(kso.triggered(), false);

        vm.expectRevert("KillSwitchOracle/price-above-threshold");
        kso.trigger(WBTC_BTC_ORACLE);

        vm.expectRevert("KillSwitchOracle/price-above-threshold");
        kso.trigger(STETH_ETH_ORACLE);

        // TODO force update the oracles to a low value to test triggering
    }

    function testCapAutomatorConfiguration() public {
        // FIXME: This will fail until previous spell passes
        _assertSupplyCapConfig({
            asset:            WBTC,
            max:              6_000,
            gap:              500,
            increaseCooldown: 12 hours
        });
        _assertBorrowCapConfig({
            asset:            WETH,
            max:              1_000_000,
            gap:              10_000,
            increaseCooldown: 12 hours
        });

        GovHelpers.executePayload(vm, payload, executor);

        _assertSupplyCapConfig({
            asset:            WBTC,
            max:              10_000,
            gap:              500,
            increaseCooldown: 12 hours
        });
        _assertBorrowCapConfig({
            asset:            WETH,
            max:              1_000_000,
            gap:              20_000,
            increaseCooldown: 12 hours
        });
    }

}
