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

import { IAToken } from "lib/aave-v3-core/contracts/interfaces/IAToken.sol";

import { PullRewardsTransferStrategy } from "lib/aave-v3-periphery/contracts/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";
import { IRewardsController }          from "lib/aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";

contract SparkEthereum_20240110TestBase is SparkEthereumTestBase {

    address constant EMISSION_MANAGER      = 0xf09e48dd4CA8e76F63a57ADd428bB06fee7932a4;
    address constant INCENTIVES_CONTROLLER = 0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    address constant REWARDS_OPERATOR      = 0x8076807464DaC94Ac8Aa1f7aF31b58F73bD88A27;

    address constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant GNO    = 0x6810e776880C02933D47DB1b9fc05908e5386b96;
    address constant RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address constant USDC   = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT   = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WBTC   = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    constructor() {
        id = '20240110';
    }

    function setUp() public virtual {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18934612);  // Jan 4, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}

contract SparkEthereum_20240110SpellTest is SparkEthereum_20240110TestBase {

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

        assertEq(strategy.getIncentivesController(), INCENTIVES_CONTROLLER);
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
        assertIncentivesController(GNO,    address(0));
        assertIncentivesController(RETH,   INCENTIVES_CONTROLLER);
        assertIncentivesController(SDAI,   address(0));
        assertIncentivesController(USDC,   address(0));
        assertIncentivesController(USDT,   INCENTIVES_CONTROLLER);
        assertIncentivesController(WBTC,   address(0));
        assertIncentivesController(WETH,   address(0));
        assertIncentivesController(WSTETH, address(0));

        GovHelpers.executePayload(vm, payload, executor);

        assertIncentivesController(DAI,    INCENTIVES_CONTROLLER);
        assertIncentivesController(GNO,    INCENTIVES_CONTROLLER);
        assertIncentivesController(RETH,   INCENTIVES_CONTROLLER);
        assertIncentivesController(SDAI,   INCENTIVES_CONTROLLER);
        assertIncentivesController(USDC,   INCENTIVES_CONTROLLER);
        assertIncentivesController(USDT,   INCENTIVES_CONTROLLER);
        assertIncentivesController(WBTC,   INCENTIVES_CONTROLLER);
        assertIncentivesController(WETH,   INCENTIVES_CONTROLLER);
        assertIncentivesController(WSTETH, INCENTIVES_CONTROLLER);
    }

}

contract SparkEthereum_20240110RewardsE2ETest is SparkEthereum_20240110TestBase {

    address constant POOL              = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address constant WETH_ATOKEN       = 0x59cD1C87501baa753d0B5B5Ab5D8416A45cD71DB;
    address constant TRANSFER_STRATEGY = 0x11aAC1cA5822cf8Ba6d06B0d84901940c0EE36d8;

    IAToken            wethAToken           = IAToken(WETH_ATOKEN);
    IERC20             wsteth               = IERC20(WSTETH);
    IRewardsController incentivesController = IRewardsController(INCENTIVES_CONTROLLER);

    uint256 REWARD_AMOUNT = 20 ether;
    uint256 DURATION      = 30 days;
    uint256 STETH_INDEX   = 1.1525e18; // Approximate conversion rate for approx APY calcs

    function setUp() public override {
        super.setUp();

        GovHelpers.executePayload(vm, payload, executor);

        deal(WSTETH, REWARDS_OPERATOR, REWARD_AMOUNT);

        vm.prank(REWARDS_OPERATOR);
        wsteth.approve(TRANSFER_STRATEGY, type(uint256).max);
    }

    function test_claimAllRewards_singleUser() public {
        address user = makeAddr("user");

        deal(WETH, user, 100 ether);

        vm.startPrank(user);

        IERC20(WETH).approve(POOL, 100 ether);
        IPool(POOL).supply(WETH, 100 ether, user, 0);

        address claimAddress = makeAddr("claimAddress");
        address[] memory assets = new address[](1);
        assets[0] = WETH_ATOKEN;

        incentivesController.claimAllRewards(assets, claimAddress);

        assertEq(wsteth.balanceOf(claimAddress),     0);
        assertEq(wsteth.balanceOf(REWARDS_OPERATOR), REWARD_AMOUNT);

        uint256 expectedTotalRewards = _getTotalExpectedRewards(user);

        // Sanity check: ~0.11% APY
        assertEq(expectedTotalRewards, 0.008178471705486100 ether);
        assertEq(expectedTotalRewards * STETH_INDEX * 365 / 30 / wethAToken.balanceOf(user), 0.001146792117936348e18);

        skip(DURATION / 4);  // 25% of rewards distributed

        incentivesController.claimAllRewards(assets, claimAddress);

        assertApproxEqAbs(wsteth.balanceOf(claimAddress),     expectedTotalRewards / 4,                   100);
        assertApproxEqAbs(wsteth.balanceOf(REWARDS_OPERATOR), REWARD_AMOUNT - (expectedTotalRewards / 4), 100);

        // Assert diffs are equal and opposite, with rounding going towards REWARDS_OPERATOR
        assertEq(
            (expectedTotalRewards / 4) - wsteth.balanceOf(claimAddress),
            wsteth.balanceOf(REWARDS_OPERATOR) - (REWARD_AMOUNT - (expectedTotalRewards / 4))
        );

        skip(DURATION * 3 / 4);  // Warp to the end, distributing the remaining 75% of rewards

        incentivesController.claimAllRewards(assets, claimAddress);

        assertApproxEqAbs(wsteth.balanceOf(claimAddress),     expectedTotalRewards,                 200);
        assertApproxEqAbs(wsteth.balanceOf(REWARDS_OPERATOR), REWARD_AMOUNT - expectedTotalRewards, 200);

        // Assert diffs are equal and opposite, with rounding going towards REWARDS_OPERATOR
        assertEq(
            expectedTotalRewards - wsteth.balanceOf(claimAddress),
            wsteth.balanceOf(REWARDS_OPERATOR) - (REWARD_AMOUNT - expectedTotalRewards)
        );

        skip(DURATION / 4);  // Warp past the end to show that rewards no longer accrue

        uint256 beforeBalance = wsteth.balanceOf(claimAddress);

        incentivesController.claimAllRewards(assets, claimAddress);

        assertEq(wsteth.balanceOf(claimAddress), beforeBalance);
    }

    function test_claimAllRewards_multiUser() public {
        address whale1 = 0xf8dE75c7B95edB6f1E639751318f117663021Cf0;
        address whale2 = 0xAA1582084c4f588eF9BE86F5eA1a919F86A3eE57;

        address claimAddress1 = makeAddr("claimAddress1");
        address claimAddress2 = makeAddr("claimAddress2");

        address[] memory assets = new address[](1);
        assets[0] = WETH_ATOKEN;

        // 1. First claim, no balance changes

        vm.prank(whale1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        vm.prank(whale2);
        incentivesController.claimAllRewards(assets, claimAddress2);

        assertEq(wsteth.balanceOf(claimAddress1),    0);
        assertEq(wsteth.balanceOf(claimAddress2),    0);
        assertEq(wsteth.balanceOf(REWARDS_OPERATOR), REWARD_AMOUNT);

        // 2. Calculate expected rewards

        uint256 expectedTotalRewards1 = _getTotalExpectedRewards(whale1);
        uint256 expectedTotalRewards2 = _getTotalExpectedRewards(whale2);

        // Sanity check: 6.5 ether * 365 / 30 / 100 ether * 100% * 1.15 conversion = ~0.11% APY
        assertEq(expectedTotalRewards1, 6.488055402975879300 ether);
        assertEq(expectedTotalRewards2, 3.029641375200069260 ether);

        // Sanity check: ~0.11% APY, cache to variable to show that APYs are exactly equal for both users
        uint256 expectedApy = 0.001147261260124086e18;
        assertEq(expectedTotalRewards1 * STETH_INDEX * 365 / 30 / wethAToken.balanceOf(whale1), expectedApy);
        assertEq(expectedTotalRewards2 * STETH_INDEX * 365 / 30 / wethAToken.balanceOf(whale2), expectedApy);

        skip(DURATION / 4);  // 25% of rewards distributed

        vm.prank(whale1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        vm.prank(whale2);
        incentivesController.claimAllRewards(assets, claimAddress2);

        assertApproxEqAbs(wsteth.balanceOf(claimAddress1), expectedTotalRewards1 / 4, 100_000);
        assertApproxEqAbs(wsteth.balanceOf(claimAddress2), expectedTotalRewards2 / 4, 100_000);

        assertApproxEqAbs(
            wsteth.balanceOf(REWARDS_OPERATOR),
            REWARD_AMOUNT - (expectedTotalRewards1 / 4) - (expectedTotalRewards2 / 4),
            100_000
        );

        // Assert diffs are equal and opposite, with rounding going towards REWARDS_OPERATOR
        assertEq(
            ((expectedTotalRewards1 / 4) - wsteth.balanceOf(claimAddress1)) + ((expectedTotalRewards2 / 4) - wsteth.balanceOf(claimAddress2)),
            wsteth.balanceOf(REWARDS_OPERATOR) - (REWARD_AMOUNT - (expectedTotalRewards1 / 4) - (expectedTotalRewards2 / 4))
        );

        skip(DURATION * 3 / 4);  // Warp to the end, distributing the remaining 75% of rewards

        vm.prank(whale1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        vm.prank(whale2);
        incentivesController.claimAllRewards(assets, claimAddress2);

        assertApproxEqAbs(wsteth.balanceOf(claimAddress1), expectedTotalRewards1, 200_000);
        assertApproxEqAbs(wsteth.balanceOf(claimAddress2), expectedTotalRewards2, 200_000);

        assertApproxEqAbs(
            wsteth.balanceOf(REWARDS_OPERATOR),
            REWARD_AMOUNT - (expectedTotalRewards1) - (expectedTotalRewards2),
            300_000
        );

        // Assert diffs are equal and opposite, with rounding going towards REWARDS_OPERATOR
        assertEq(
            ((expectedTotalRewards1) - wsteth.balanceOf(claimAddress1)) + ((expectedTotalRewards2) - wsteth.balanceOf(claimAddress2)),
            wsteth.balanceOf(REWARDS_OPERATOR) - (REWARD_AMOUNT - (expectedTotalRewards1) - (expectedTotalRewards2))
        );
    }

    function _getTotalExpectedRewards(address user) internal view returns (uint256 expectedTotalRewards) {
        expectedTotalRewards = _getExpectedRewards(user, DURATION);
    }

    function _getExpectedRewards(address user, uint256 earningDuration)
        internal view returns (uint256 expectedRewards)
    {
        uint256 rewardShare = wethAToken.scaledBalanceOf(user) * 1e18 / wethAToken.scaledTotalSupply();

        expectedRewards = REWARD_AMOUNT * rewardShare * earningDuration / 1e18 / DURATION;
    }

}
