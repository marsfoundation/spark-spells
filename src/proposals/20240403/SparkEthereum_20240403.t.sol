// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { ReserveConfiguration } from "lib/aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";

import { IKillSwitchOracle } from 'src/interfaces/IKillSwitchOracle.sol';

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
}

contract MockAggregator {

    int256 public latestAnswer;

    constructor(int256 _latestAnswer) {
        latestAnswer = _latestAnswer;
    }
    
}

contract SparkEthereum_20240403Test is SparkEthereumTestBase {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

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

        assertEq(aclManager.isRiskAdmin(KILL_SWITCH_ORACLE), false);
        assertEq(kso.numOracles(),                           0);
        assertEq(kso.oracleThresholds(WBTC_BTC_ORACLE),      0);
        assertEq(kso.oracleThresholds(STETH_ETH_ORACLE),     0);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(aclManager.isRiskAdmin(KILL_SWITCH_ORACLE), true);
        assertEq(kso.numOracles(),                           2);
        assertEq(kso.oracleThresholds(WBTC_BTC_ORACLE),      0.95e8);
        assertEq(kso.oracleThresholds(STETH_ETH_ORACLE),     0.95e18);
        
        // Sanity check the latest answers
        assertEq(IChainlinkAggregator(WBTC_BTC_ORACLE).latestAnswer(),  0.99897716e8);
        assertEq(IChainlinkAggregator(STETH_ETH_ORACLE).latestAnswer(), 0.999478607275791200e18);

        // Should not be able to trigger either
        vm.expectRevert("KillSwitchOracle/price-above-threshold");
        kso.trigger(WBTC_BTC_ORACLE);
        vm.expectRevert("KillSwitchOracle/price-above-threshold");
        kso.trigger(STETH_ETH_ORACLE);

        // Replace both Chainlink aggregators with MockAggregators reporting below
        // threshold prices
        vm.store(
            WBTC_BTC_ORACLE,
            bytes32(uint256(2)),
            bytes32((uint256(uint160(address(new MockAggregator(0.95e8)))) << 16) | 1)
        );
        vm.store(
            STETH_ETH_ORACLE,
            bytes32(uint256(2)),
            bytes32((uint256(uint160(address(new MockAggregator(0.95e18)))) << 16) | 1)
        );

        assertEq(IChainlinkAggregator(WBTC_BTC_ORACLE).latestAnswer(),  0.95e8);
        assertEq(IChainlinkAggregator(STETH_ETH_ORACLE).latestAnswer(), 0.95e18);

        assertEq(kso.triggered(),           false);
        assertEq(_getBorrowEnabled(DAI),    true);
        assertEq(_getBorrowEnabled(SDAI),   false);
        assertEq(_getBorrowEnabled(USDC),   true);
        assertEq(_getBorrowEnabled(WETH),   true);
        assertEq(_getBorrowEnabled(WSTETH), true);
        assertEq(_getBorrowEnabled(WBTC),   true);
        assertEq(_getBorrowEnabled(GNO),    false);
        assertEq(_getBorrowEnabled(RETH),   true);
        assertEq(_getBorrowEnabled(USDT),   true);

        uint256 snapshotId = vm.snapshot();
        kso.trigger(WBTC_BTC_ORACLE);

        assertEq(kso.triggered(),           true);
        assertEq(_getBorrowEnabled(DAI),    false);
        assertEq(_getBorrowEnabled(SDAI),   false);
        assertEq(_getBorrowEnabled(USDC),   false);
        assertEq(_getBorrowEnabled(WETH),   false);
        assertEq(_getBorrowEnabled(WSTETH), false);
        assertEq(_getBorrowEnabled(WBTC),   false);
        assertEq(_getBorrowEnabled(GNO),    false);
        assertEq(_getBorrowEnabled(RETH),   false);
        assertEq(_getBorrowEnabled(USDT),   false);

        vm.revertTo(snapshotId);

        assertEq(kso.triggered(),           false);
        assertEq(_getBorrowEnabled(DAI),    true);
        assertEq(_getBorrowEnabled(SDAI),   false);
        assertEq(_getBorrowEnabled(USDC),   true);
        assertEq(_getBorrowEnabled(WETH),   true);
        assertEq(_getBorrowEnabled(WSTETH), true);
        assertEq(_getBorrowEnabled(WBTC),   true);
        assertEq(_getBorrowEnabled(GNO),    false);
        assertEq(_getBorrowEnabled(RETH),   true);
        assertEq(_getBorrowEnabled(USDT),   true);
        
        kso.trigger(STETH_ETH_ORACLE);

        assertEq(kso.triggered(),           true);
        assertEq(_getBorrowEnabled(DAI),    false);
        assertEq(_getBorrowEnabled(SDAI),   false);
        assertEq(_getBorrowEnabled(USDC),   false);
        assertEq(_getBorrowEnabled(WETH),   false);
        assertEq(_getBorrowEnabled(WSTETH), false);
        assertEq(_getBorrowEnabled(WBTC),   false);
        assertEq(_getBorrowEnabled(GNO),    false);
        assertEq(_getBorrowEnabled(RETH),   false);
        assertEq(_getBorrowEnabled(USDT),   false);
    }

    function _getBorrowEnabled(address asset) internal view returns (bool) {
        return pool.getConfiguration(asset).getBorrowingEnabled();
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
