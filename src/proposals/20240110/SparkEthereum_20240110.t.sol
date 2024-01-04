// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { ISparkLendFreezerMom }   from './ISparkLendFreezerMom.sol';
import {
    SparkEthereum_20240110,
    IIncentivizedERC20,
    DataTypes,
    IEACAggregatorProxy
} from './SparkEthereum_20240110.sol';

import { PullRewardsTransferStrategy } from "aave-v3-periphery/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";

contract SparkEthereum_20240110Test is SparkEthereumTestBase {

    address constant EMISSION_MANAGER   = 0xf09e48dd4CA8e76F63a57ADd428bB06fee7932a4;
    address constant REWARDS_CONTROLLER = 0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    address constant REWARDS_OPERATOR   = 0x8076807464DaC94Ac8Aa1f7aF31b58F73bD88A27;

    address constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC   = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT   = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant GNO    = 0x6810e776880C02933D47DB1b9fc05908e5386b96;
    address constant RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address constant WBTC   = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    constructor() {
        id = '20240110';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18934612);  // Jan 4, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testFreezerMomDeploy() public {
        ISparkLendFreezerMom freezerMom = ISparkLendFreezerMom(SparkEthereum_20240110(payload).FREEZER_MOM());

        assertEq(freezerMom.poolConfigurator(), address(poolConfigurator));
        assertEq(freezerMom.pool(),             address(pool));
        assertEq(freezerMom.owner(),            executor);
        assertEq(freezerMom.authority(),        address(0));  // Set in spell
    }

    function testDaiOracleDeploy() public {
        IEACAggregatorProxy oracle = IEACAggregatorProxy(SparkEthereum_20240110(payload).DAI_ORACLE());

        assertEq(oracle.latestAnswer(), 1e8);
    }

    function testTransferStrategyDeploy() public {
        PullRewardsTransferStrategy strategy = PullRewardsTransferStrategy(SparkEthereum_20240110(payload).TRANSFER_STRATEGY());

        assertEq(strategy.getIncentivesController(), REWARDS_CONTROLLER);
        assertEq(strategy.getRewardsAdmin(),         executor);
        assertEq(strategy.getRewardsVault(),         REWARDS_OPERATOR);
    }

    function assertIncentivesController(address asset, address incentivesController) internal {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);
        assertEq(IIncentivizedERC20(reserveData.aTokenAddress).getIncentivesController(),            incentivesController);
        assertEq(IIncentivizedERC20(reserveData.variableDebtTokenAddress).getIncentivesController(), incentivesController);
        assertEq(IIncentivizedERC20(reserveData.stableDebtTokenAddress).getIncentivesController(),   incentivesController);
    }

    function testUpdateRewardsController() public {
        assertIncentivesController(DAI,    address(0));
        assertIncentivesController(USDC,   address(0));
        assertIncentivesController(USDT,   REWARDS_CONTROLLER);
        assertIncentivesController(GNO,    address(0));
        assertIncentivesController(RETH,   REWARDS_CONTROLLER);
        assertIncentivesController(SDAI,   address(0));
        assertIncentivesController(WBTC,   address(0));
        assertIncentivesController(WETH,   address(0));
        assertIncentivesController(WSTETH, address(0));

        GovHelpers.executePayload(vm, payload, executor);

        assertIncentivesController(DAI,    REWARDS_CONTROLLER);
        assertIncentivesController(USDC,   REWARDS_CONTROLLER);
        assertIncentivesController(USDT,   REWARDS_CONTROLLER);
        assertIncentivesController(GNO,    REWARDS_CONTROLLER);
        assertIncentivesController(RETH,   REWARDS_CONTROLLER);
        assertIncentivesController(SDAI,   REWARDS_CONTROLLER);
        assertIncentivesController(WBTC,   REWARDS_CONTROLLER);
        assertIncentivesController(WETH,   REWARDS_CONTROLLER);
        assertIncentivesController(WSTETH, REWARDS_CONTROLLER);
    }

}
