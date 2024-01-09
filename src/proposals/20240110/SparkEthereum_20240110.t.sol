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
import { IEmissionManager }            from "lib/aave-v3-periphery/contracts/rewards/interfaces/IEmissionManager.sol";
import { IRewardsController }          from "lib/aave-v3-periphery/contracts/rewards/interfaces/IRewardsController.sol";

contract SparkEthereum_20240110Test is SparkEthereumTestBase {

    address constant AUTHORITY             = 0x0a3f6849f78076aefaDf113F5BED87720274dDC0;
    address constant EMISSION_MANAGER      = 0xf09e48dd4CA8e76F63a57ADd428bB06fee7932a4;
    address constant FREEZER_MOM           = 0xFA36c12Bc307b40c701D65d8FE8F88cCEdE2277a;
    address constant INCENTIVES_CONTROLLER = 0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    address constant POOL                  = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address constant REWARDS_OPERATOR      = 0x8076807464DaC94Ac8Aa1f7aF31b58F73bD88A27;
    address constant TRANSFER_STRATEGY     = 0x11aAC1cA5822cf8Ba6d06B0d84901940c0EE36d8;
    address constant WETH_ATOKEN           = 0x59cD1C87501baa753d0B5B5Ab5D8416A45cD71DB;

    address constant DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant GNO    = 0x6810e776880C02933D47DB1b9fc05908e5386b96;
    address constant RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address constant USDC   = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT   = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WBTC   = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address public constant DAI_ORACLE_OLD    = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address public constant DAI_ORACLE_NEW    = 0x42a03F81dd8A1cEcD746dc262e4d1CD9fD39F777;
    address public constant WSTETH_ORACLE_OLD = 0xA9F30e6ED4098e9439B2ac8aEA2d3fc26BcEbb45;
    address public constant WSTETH_ORACLE_NEW = 0x8B6851156023f4f5A66F68BEA80851c3D905Ac93;

    address constant WHALE1   = 0xf8dE75c7B95edB6f1E639751318f117663021Cf0;
    address constant WHALE2   = 0xAA1582084c4f588eF9BE86F5eA1a919F86A3eE57;
    address constant GNO_USER = 0xe1d0508d4976Bd4b8552fBe5c31Cc0F023258f0C;  // Has a small GNO position

    address constant CURRENT_HAT = 0x4F09EbaA1A5e52EB95c97f3b9fa3fb398D004698;  // Happens to be the last passed spell

    ISparkLendFreezerMom        freezerMom           = ISparkLendFreezerMom(FREEZER_MOM);
    IEACAggregatorProxy         daiOracle            = IEACAggregatorProxy(DAI_ORACLE_NEW);
    PullRewardsTransferStrategy rewardStrategy       = PullRewardsTransferStrategy(TRANSFER_STRATEGY);
    IAToken                     wethAToken           = IAToken(WETH_ATOKEN);
    IERC20                      wsteth               = IERC20(WSTETH);
    IRewardsController          incentivesController = IRewardsController(INCENTIVES_CONTROLLER);

    uint256 REWARD_AMOUNT = 20 ether;
    uint256 DURATION      = 30 days;

    address claimAddress1 = makeAddr("claimAddress1");
    address claimAddress2 = makeAddr("claimAddress2");

    constructor() {
        id = '20240110';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18970183);  // Jan 9, 2024
        payload = 0x7E73CCAA4977A5429fD1815130804769EcAad4a7;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    // --- Configuration Changes ---

    function test_freezerMomDeployAndConfiguration() public {
        assertEq(freezerMom.poolConfigurator(), address(poolConfigurator));
        assertEq(freezerMom.pool(),             address(pool));
        assertEq(freezerMom.owner(),            executor);
        assertEq(freezerMom.authority(),        address(0));  // Set in spell

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(freezerMom.poolConfigurator(), address(poolConfigurator));
        assertEq(freezerMom.pool(),             address(pool));
        assertEq(freezerMom.owner(),            executor);
        assertEq(freezerMom.authority(),        AUTHORITY);
    }

    function test_daiOracleDeploy() public {
        assertEq(daiOracle.latestAnswer(), 1e8);
    }

    function test_transferStrategyDeploy() public {
        assertEq(rewardStrategy.getIncentivesController(), INCENTIVES_CONTROLLER);
        assertEq(rewardStrategy.getRewardsAdmin(),         executor);
        assertEq(rewardStrategy.getRewardsVault(),         REWARDS_OPERATOR);
    }

    function assertIncentivesController(address asset, address _incentivesController) internal {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);
        assertEq(IIncentivizedERC20(reserveData.aTokenAddress).getIncentivesController(),            _incentivesController);
        assertEq(IIncentivizedERC20(reserveData.variableDebtTokenAddress).getIncentivesController(), _incentivesController);
        assertEq(IIncentivizedERC20(reserveData.stableDebtTokenAddress).getIncentivesController(),   _incentivesController);
    }

    function test_updateRewardsController() public {
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

    function test_marketConfigChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory gnoConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'GNO');
        assertEq(gnoConfigBefore.ltv,      20_00);
        assertEq(gnoConfigBefore.isFrozen, false);

        _validateAssetSourceOnOracle(poolAddressesProvider, DAI,    DAI_ORACLE_OLD);
        _validateAssetSourceOnOracle(poolAddressesProvider, WSTETH, WSTETH_ORACLE_OLD);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        gnoConfigBefore.ltv      = 0;
        gnoConfigBefore.isFrozen = true;
        _validateReserveConfig(gnoConfigBefore, allConfigsAfter);

        _validateAssetSourceOnOracle(poolAddressesProvider, DAI,    DAI_ORACLE_NEW);
        _validateAssetSourceOnOracle(poolAddressesProvider, WSTETH, WSTETH_ORACLE_NEW);
    }

    function test_aclChanges() public {
        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM), false);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM), false);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(aclManager.isEmergencyAdmin(FREEZER_MOM), true);
        assertEq(aclManager.isRiskAdmin(FREEZER_MOM), true);
    }

    function test_rewardsConfiguration() public {
        assertEq(IEmissionManager(EMISSION_MANAGER).getEmissionAdmin(WSTETH), address(0));
        (
            uint256 index,
            uint256 emissionPerSecond,
            uint256 lastUpdateTimestamp,
            uint256 distributionEnd
        ) = incentivesController.getRewardsData(WETH_ATOKEN, WSTETH);
        assertEq(index,                                            0);
        assertEq(emissionPerSecond,                                0);
        assertEq(lastUpdateTimestamp,                              0);
        assertEq(distributionEnd,                                  0);
        assertEq(incentivesController.getTransferStrategy(WSTETH), address(0));
        assertEq(incentivesController.getRewardOracle(WSTETH),     address(0));

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(IEmissionManager(EMISSION_MANAGER).getEmissionAdmin(WSTETH), REWARDS_OPERATOR);
        (
            index,
            emissionPerSecond,
            lastUpdateTimestamp,
            distributionEnd
        ) = incentivesController.getRewardsData(WETH_ATOKEN, WSTETH);
        assertEq(index,                                            0);
        assertEq(emissionPerSecond,                                REWARD_AMOUNT / DURATION);
        assertEq(lastUpdateTimestamp,                              block.timestamp);
        assertEq(distributionEnd,                                  block.timestamp + DURATION);
        assertEq(incentivesController.getTransferStrategy(WSTETH), TRANSFER_STRATEGY);
        assertEq(incentivesController.getRewardOracle(WSTETH),     WSTETH_ORACLE_NEW);
    }

    // --- E2E Testing ---

    function _setUpRewards() internal {
        GovHelpers.executePayload(vm, payload, executor);

        deal(WSTETH, REWARDS_OPERATOR, REWARD_AMOUNT);
    }

    function test_claimAllRewards_singleUser() public {
        _setUpRewards();

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

        // Sanity check: 100 / 238k supplied (~0.04%) which gives them ~0.04% of the rewards (0.0004 * 20 = 0.008)
        assertEq(expectedTotalRewards, 0.008388171771033220 ether);

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
        _setUpRewards();

        address[] memory assets = new address[](1);
        assets[0] = WETH_ATOKEN;

        // 1. First claim, no balance changes

        vm.prank(WHALE1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        vm.prank(WHALE2);
        incentivesController.claimAllRewards(assets, claimAddress2);

        assertEq(wsteth.balanceOf(claimAddress1),    0);
        assertEq(wsteth.balanceOf(claimAddress2),    0);
        assertEq(wsteth.balanceOf(REWARDS_OPERATOR), REWARD_AMOUNT);

        // 2. Calculate expected rewards

        uint256 expectedTotalRewards1 = _getTotalExpectedRewards(WHALE1);
        uint256 expectedTotalRewards2 = _getTotalExpectedRewards(WHALE2);

        // Sanity check: WHALE1 has 79k / 238k supplied (~33%) which gives them ~33% of the rewards (0.33 * 20 = 6.66)
        assertEq(expectedTotalRewards1, 6.655739385653780540 ether);
        // Sanity check: WHALE2 has 37k / 238k supplied (~15.5%) which gives them ~15.5% of the rewards (0.155 * 20 = 3.1)
        assertEq(expectedTotalRewards2, 3.107942545631857880 ether);

        skip(DURATION / 4);  // 25% of rewards distributed

        vm.prank(WHALE1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        vm.prank(WHALE2);
        incentivesController.claimAllRewards(assets, claimAddress2);

        assertApproxEqAbs(wsteth.balanceOf(claimAddress1), expectedTotalRewards1 / 4, 100_000);
        assertApproxEqAbs(wsteth.balanceOf(claimAddress2), expectedTotalRewards2 / 4, 100_000);

        assertApproxEqAbs(
            wsteth.balanceOf(REWARDS_OPERATOR),
            REWARD_AMOUNT - (expectedTotalRewards1 / 4) - (expectedTotalRewards2 / 4),
            150_000
        );

        // Assert diffs are equal and opposite, with rounding going towards REWARDS_OPERATOR
        assertEq(
            ((expectedTotalRewards1 / 4) - wsteth.balanceOf(claimAddress1)) + ((expectedTotalRewards2 / 4) - wsteth.balanceOf(claimAddress2)),
            wsteth.balanceOf(REWARDS_OPERATOR) - (REWARD_AMOUNT - (expectedTotalRewards1 / 4) - (expectedTotalRewards2 / 4))
        );

        skip(DURATION * 3 / 4);  // Warp to the end, distributing the remaining 75% of rewards

        vm.prank(WHALE1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        vm.prank(WHALE2);
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

    // NOTE: For the below tests, they demonstrate that the incentivesController works correctly in context of the
    //       aToken. If the aToken is not configured correctly, the rewards are given out based on the users CURRENT balance
    //       and the amount of time since they've accrued the rewards. This means that if a user changes their balance and claims,
    //       they would get a reward distribution that would be as if they had that balance the whole time since the last update.
    //       The incentivesController updates the state on every balance change so this wouldn't be possible.

    function test_claimAllRewards_transferAfterWarp() external {
        _setUpRewards();

        address[] memory assets = new address[](1);
        assets[0] = WETH_ATOKEN;

        // 1. Warp halfway through the rewards period

        skip(DURATION / 2);

        // 2. Snapshot state

        uint256 snapshot = vm.snapshot();

        // 3. Claim rewards for whale 1 (without transfer)

        vm.prank(WHALE1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        uint256 firstClaimAmount = wsteth.balanceOf(claimAddress1);

        // 4. Revert to reset state to before claim

        vm.revertTo(snapshot);

        // 5. Transfer 10% of staked tokens to new address

        address newAddress = makeAddr("newAddress");

        vm.startPrank(WHALE1);
        wethAToken.transfer(newAddress, wethAToken.balanceOf(WHALE1) / 10);
        vm.stopPrank();

        // 6. Claim rewards for whale 1 (with transfer)

        vm.prank(WHALE1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        // 7. Assert that the second claim is the same as before, meaning the transfer updated the
        //    accrued rewards for the user.

        assertEq(wsteth.balanceOf(claimAddress1), firstClaimAmount);

        // 8. Claim rewards with the new address, this shouldn't have any rewards since no time has
        //    passed.

        vm.prank(newAddress);
        incentivesController.claimAllRewards(assets, claimAddress2);

        assertEq(wsteth.balanceOf(claimAddress2), 0);
    }

    function test_claimAllRewards_transferAfterWarpAndClaim() external {
        _setUpRewards();

        address[] memory assets = new address[](1);
        assets[0] = WETH_ATOKEN;

        // 1. Warp halfway through the rewards period

        skip(DURATION / 2);

        // 2. Snapshot state

        uint256 snapshot = vm.snapshot();

        // 3. Claim rewards for whale 1 (without transfer)

        vm.prank(WHALE1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        uint256 firstClaimAmount = wsteth.balanceOf(claimAddress1);

        // 4. Revert to reset state to before claim

        vm.revertTo(snapshot);

        // 5. Claim rewards after 15 days (without transfer)

        vm.prank(WHALE1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        // 6. Transfer 10% of staked tokens to new address and claim from this address

        address newAddress = makeAddr("newAddress");

        vm.startPrank(WHALE1);
        wethAToken.transfer(newAddress, wethAToken.balanceOf(WHALE1) / 10);
        vm.stopPrank();

        // 8. Claim rewards with the new address, this shouldn't have any rewards since no time has
        //    passed.

        vm.prank(newAddress);
        incentivesController.claimAllRewards(assets, claimAddress2);

        // Without an update, claimAddress2 would have a non-zero balance and claimAddress1
        // would have the same amount
        assertEq(wsteth.balanceOf(claimAddress1), firstClaimAmount);
        assertEq(wsteth.balanceOf(claimAddress2), 0);
    }

    // NOTE: `AfterWarpAndClaim` tests don't apply to supply and withdraw, because changing the balance
    //       after the claim results in a balance change of the SAME user, unlike a transfer. Because of
    //       this, the accrued rewards state has been updated for the user regardless.

    function test_claimAllRewards_supplyAfterWarp() external {
        _setUpRewards();

        address[] memory assets = new address[](1);
        assets[0] = WETH_ATOKEN;

        vm.startPrank(WHALE1);

        // 1. Warp halfway through the rewards period

        skip(DURATION / 2);

        // 2. Snapshot state

        uint256 snapshot = vm.snapshot();

        // 3. Claim rewards for whale 1 (without supply)

        incentivesController.claimAllRewards(assets, claimAddress1);

        uint256 firstClaimAmount = wsteth.balanceOf(claimAddress1);

        // 4. Revert to reset state to before claim

        vm.revertTo(snapshot);

        // 5. Supply 10% of more tokens

        vm.startPrank(WHALE1);

        uint256 amount = wethAToken.balanceOf(WHALE1) / 10;

        deal(WETH, WHALE1, amount);

        IERC20(WETH).approve(POOL, amount);
        IPool(POOL).supply(WETH, amount, WHALE1, 0);

        vm.stopPrank();

        // 6. Claim rewards for whale 1 (with supply)

        vm.prank(WHALE1);
        incentivesController.claimAllRewards(assets, claimAddress1);

        // 7. Assert that the second claim are is same as before, meaning the mint updated the
        //    accrued rewards for the user.

        assertEq(wsteth.balanceOf(claimAddress1), firstClaimAmount);
    }

    function test_claimAllRewards_withdrawAfterWarp() external {
        _setUpRewards();

        address[] memory assets = new address[](1);
        assets[0] = WETH_ATOKEN;

        vm.startPrank(WHALE1);

        // 1. Warp halfway through the rewards period

        skip(DURATION / 2);

        // 2. Snapshot state

        uint256 snapshot = vm.snapshot();

        // 3. Claim rewards for whale 1 (without withdraw)

        incentivesController.claimAllRewards(assets, claimAddress1);

        uint256 firstClaimAmount = wsteth.balanceOf(claimAddress1);

        // 4. Revert to reset state to before claim

        vm.revertTo(snapshot);

        // 5. Withdraw 10% of tokens

        uint256 amount = wethAToken.balanceOf(WHALE1) / 10;

        IPool(POOL).withdraw(WETH, amount, WHALE1);

        // 6. Claim rewards for whale 1 (with withdraw)

        incentivesController.claimAllRewards(assets, claimAddress1);

        // 7. Assert that the second claim are is same as before, meaning the burn updated the
        //    accrued rewards for the user.

        assertEq(wsteth.balanceOf(claimAddress1), firstClaimAmount);
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

    function assertFrozen(string memory assetSymbol, bool frozen) internal {
        assertEq(_findReserveConfigBySymbol(createConfigurationSnapshot('', pool), assetSymbol).isFrozen, frozen);
    }

    function assertPaused(string memory assetSymbol, bool paused) internal {
        assertEq(_findReserveConfigBySymbol(createConfigurationSnapshot('', pool), assetSymbol).isPaused, paused);
    }

    function test_freezerMomE2E() public {
        GovHelpers.executePayload(vm, payload, executor);

        // Sanity checks - cannot call Freezer Mom unless you have the hat
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.freezeMarket(DAI, true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.freezeAllMarkets(true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.pauseMarket(DAI, true);
        vm.expectRevert("SparkLendFreezerMom/not-authorized");
        freezerMom.pauseAllMarkets(true);

        // Pretend the hat has logic to freeze
        assertFrozen('DAI',  false);
        assertFrozen('WETH', false);
        vm.prank(CURRENT_HAT);
        freezerMom.freezeMarket(DAI, true);
        assertFrozen('DAI',  true);
        assertFrozen('WETH', false);

        vm.prank(CURRENT_HAT);
        freezerMom.freezeAllMarkets(true);
        assertFrozen('DAI',  true);
        assertFrozen('WETH', true);

        assertPaused('DAI',  false);
        assertPaused('WETH', false);
        vm.prank(CURRENT_HAT);
        freezerMom.pauseMarket(DAI, true);
        assertPaused('DAI',  true);
        assertPaused('WETH', false);

        vm.prank(CURRENT_HAT);
        freezerMom.pauseAllMarkets(true);
        assertPaused('DAI',  true);
        assertPaused('WETH', true);
    }

    function test_gnoDisabledE2E() public {
        uint256 snapshot = vm.snapshot();

        vm.startPrank(GNO_USER);
        // User can borrow more DAI
        pool.borrow(DAI, 1, 2, 0, GNO_USER);
        // User has a dust amount still they can supply
        pool.supply(GNO, 1, GNO_USER, 0);
        vm.stopPrank();

        vm.revertTo(snapshot);

        GovHelpers.executePayload(vm, payload, executor);

        // User can no longer supply GNO or borrow against it
        vm.startPrank(GNO_USER);
        vm.expectRevert(bytes('57'));  // LTV_VALIDATION_FAILED
        pool.borrow(DAI, 1, 2, 0, GNO_USER);
        vm.expectRevert(bytes('28'));  // RESERVE_FROZEN
        pool.supply(GNO, 1, GNO_USER, 0);

        // User can still close out position
        deal(DAI, GNO_USER, 1000e18);
        IERC20(DAI).approve(address(pool), 1000e18);
        pool.repay(DAI, type(uint256).max, 2, GNO_USER);
        assertEq(IERC20(GNO).balanceOf(GNO_USER), 4832628897478086);  // Dust amount in the user's wallet
        pool.withdraw(GNO, type(uint256).max, GNO_USER);
        assertEq(IERC20(GNO).balanceOf(GNO_USER), 50104832628897478086);
        vm.stopPrank();
    }

    function test_deployedContracts() public {
        address expectedPayload = deployPayload();
        address actualPayload   = payload;

        uint256 expectedBytecodeSize = expectedPayload.code.length;
        uint256 actualBytecodeSize   = actualPayload.code.length;

        uint256 metadataLength = _getBytecodeMetadataLength(expectedPayload);
        assertTrue(metadataLength <= expectedBytecodeSize);
        expectedBytecodeSize -= metadataLength;

        metadataLength = _getBytecodeMetadataLength(actualPayload);
        assertTrue(metadataLength <= actualBytecodeSize);
        actualBytecodeSize -= metadataLength;

        assertEq(actualBytecodeSize, expectedBytecodeSize);

        uint256 size = actualBytecodeSize;
        uint256 expectedHash;
        uint256 actualHash;

        assembly {
            let ptr := mload(0x40)

            extcodecopy(expectedPayload, ptr, 0, size)
            expectedHash := keccak256(ptr, size)

            extcodecopy(actualPayload, ptr, 0, size)
            actualHash := keccak256(ptr, size)
        }

        assertEq(actualHash, expectedHash);
    }

}
