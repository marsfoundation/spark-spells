// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { ReserveConfiguration } from "lib/aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";

import { IKillSwitchOracle }                         from 'src/interfaces/IKillSwitchOracle.sol';
import { IMetaMorpho, MarketParams, PendingUint192 } from 'src/interfaces/IMetaMorpho.sol';

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

    address internal constant MORPHO_VAULT = 0x73e65DBD630f90604062f6E02fAb9138e713edD9;

    address internal constant USDE  = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

    address internal constant SUSDE_ORACLE = 0x5D916980D5Ae1737a8330Bf24dF812b2911Aae25;
    address internal constant USDE_ORACLE  = 0xaE4750d0813B5E37A51f7629beedd72AF1f9cA35;

    address internal constant MORPHO_DEFAULT_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    constructor() {
        id = '20240403';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19558521);  // April 1, 2024
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
        assertEq(IChainlinkAggregator(WBTC_BTC_ORACLE).latestAnswer(),  1.00080829e8);
        assertEq(IChainlinkAggregator(STETH_ETH_ORACLE).latestAnswer(), 0.996115045492042900e18);

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

    function testMorphoSupplyCapUpdates() public {
        MarketParams memory susde1 = MarketParams({
            loanToken:       DAI,
            collateralToken: SUSDE,
            oracle:          SUSDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.77e18
        });
        MarketParams memory susde2 = MarketParams({
            loanToken:       DAI,
            collateralToken: SUSDE,
            oracle:          SUSDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        });
        MarketParams memory susde3 = MarketParams({
            loanToken:       DAI,
            collateralToken: SUSDE,
            oracle:          SUSDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });
        MarketParams memory susde4 = MarketParams({
            loanToken:       DAI,
            collateralToken: SUSDE,
            oracle:          SUSDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.945e18
        });
        MarketParams memory usde1 = MarketParams({
            loanToken:       DAI,
            collateralToken: USDE,
            oracle:          USDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.77e18
        });
        MarketParams memory usde2 = MarketParams({
            loanToken:       DAI,
            collateralToken: USDE,
            oracle:          USDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        });
        MarketParams memory usde3 = MarketParams({
            loanToken:       DAI,
            collateralToken: USDE,
            oracle:          USDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });
        MarketParams memory usde4 = MarketParams({
            loanToken:       DAI,
            collateralToken: USDE,
            oracle:          USDE_ORACLE,
            irm:             MORPHO_DEFAULT_IRM,
            lltv:            0.945e18
        });

        _assertCap(susde1, 1_000_000_000 ether);
        _assertCap(susde2, 100_000_000 ether);
        _assertCap(susde3, 50_000_000 ether);
        _assertCap(susde4, 10_000_000 ether);
        _assertCap(usde1,  1_000_000_000 ether);
        _assertCap(usde2,  100_000_000 ether);
        _assertCap(usde3,  50_000_000 ether);
        _assertCap(usde4,  10_000_000 ether);

        GovHelpers.executePayload(vm, payload, executor);

        _assertCap(susde1, 1_000_000_000 ether);
        _assertCap(susde2, 100_000_000 ether, 200_000_000 ether);
        _assertCap(susde3, 50_000_000 ether);
        _assertCap(susde4, 10_000_000 ether);
        _assertCap(usde1,  1_000_000_000 ether);
        _assertCap(usde2,  100_000_000 ether, 500_000_000 ether);
        _assertCap(usde3,  50_000_000 ether,  200_000_000 ether);
        _assertCap(usde4,  10_000_000 ether);

        assertEq(IMetaMorpho(MORPHO_VAULT).timelock(), 1 days);

        skip(1 days);

        // These are permissionless (call coming from the test contract)
        IMetaMorpho(MORPHO_VAULT).acceptCap(susde2);
        IMetaMorpho(MORPHO_VAULT).acceptCap(usde2);
        IMetaMorpho(MORPHO_VAULT).acceptCap(usde3);

        _assertCap(susde1, 1_000_000_000 ether);
        _assertCap(susde2, 200_000_000 ether);
        _assertCap(susde3, 50_000_000 ether);
        _assertCap(susde4, 10_000_000 ether);
        _assertCap(usde1,  1_000_000_000 ether);
        _assertCap(usde2,  500_000_000 ether);
        _assertCap(usde3,  200_000_000 ether);
        _assertCap(usde4,  10_000_000 ether);
    }

    function _assertCap(
        MarketParams memory _config,
        uint256             _currentCap,
        bool                _hasPending,
        uint256             _pendingCap
    ) internal {
        bytes32 id = _id(_config);
        assertEq(IMetaMorpho(MORPHO_VAULT).config(id).cap, _currentCap);
        PendingUint192 memory pendingCap = IMetaMorpho(MORPHO_VAULT).pendingCap(id);
        if (_hasPending) {
            assertEq(pendingCap.value, _pendingCap);
            assertGt(pendingCap.validAt, 0);
        } else {
            assertEq(pendingCap.value, 0);
            assertEq(pendingCap.validAt, 0);
        }
    }

    function _assertCap(
        MarketParams memory _config,
        uint256             _currentCap,
        uint256             _pendingCap
    ) internal {
        _assertCap(_config, _currentCap, true, _pendingCap);
    }

    function _assertCap(
        MarketParams memory _config,
        uint256             _currentCap
    ) internal {
        _assertCap(_config, _currentCap, false, 0);
    }

    function _id(MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }

}
