// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./SparkBase_20241107TestBase.t.sol";

import { RateLimitHelpers } from 'lib/spark-alm-controller/src/RateLimitHelpers.sol';

interface IRateProviderLike {
    function getConversionRate() external view returns (uint256);
}

contract ForeignControllerPSMSuccessTestBase is PostSpellExecutionBaseTestBase {

    function _assertState(
        IERC20  token,
        uint256 proxyBalance,
        uint256 psmBalance,
        uint256 proxyShares,
        uint256 totalShares,
        uint256 totalAssets,
        bytes32 rateLimitKey,
        uint256 currentRateLimit
    )
        internal
    {
        address custodian = address(token) == address(usdcBase) ? pocket : address(psmBase);

        assertEq(token.balanceOf(address(almProxy)),          proxyBalance);
        assertEq(token.balanceOf(address(foreignController)), 0);  // Should always be zero
        assertEq(token.balanceOf(custodian),                  psmBalance);

        assertEq(psmBase.shares(address(almProxy)), proxyShares);
        assertEq(psmBase.totalShares(),             totalShares);
        assertEq(psmBase.totalAssets(),             totalAssets);

        bytes32 assetKey = RateLimitHelpers.makeAssetKey(rateLimitKey, address(token));

        assertEq(rateLimits.getCurrentRateLimit(assetKey), currentRateLimit);

        // Should always be 0 before and after calls
        assertEq(usdsBase.allowance(address(almProxy), address(psmBase)), 0);
    }

}

contract ForeignControllerDepositPSMFailureTests is PostSpellExecutionBaseTestBase {

    function test_depositPSM_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            foreignController.RELAYER()
        ));
        foreignController.depositPSM(address(usdsBase), 100e18);
    }

    function test_depositPSM_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.depositPSM(address(usdsBase), 100e18);
    }

    function test_depositPSM_usdsRateLimitBoundary() external {
        // Get funds from mainnet to base
        deal(address(usdsBase), address(almProxy), 10_000_000e18);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.depositPSM(address(usdsBase), 1_000_000e18 + 1);

        foreignController.depositPSM(address(usdsBase), 1_000_000e18);

        skip(1 days);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.depositPSM(address(usdsBase), 500_000e18 - 3200 + 1);

        foreignController.depositPSM(address(usdsBase), 500_000e18 - 3200);
    }

    function test_depositPSM_usdcRateLimitBoundary() external {
        // Simulate planner moving funds to base, `deal` not working
        vm.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        usdcBase.transfer(address(almProxy), 10_000_000e6);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.depositPSM(address(usdcBase), 1_000_000e6 + 1);

        foreignController.depositPSM(address(usdcBase), 1_000_000e6);

        skip(1 days);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.depositPSM(address(usdcBase), 500_000e6 - 3200 + 1);

        foreignController.depositPSM(address(usdcBase), 500_000e6 - 3200);
    }

    function test_depositPSM_susdsRateLimitBoundary() external {
        // Get funds from mainnet to base
        deal(address(susdsBase), address(almProxy), 10_000_000e18);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.depositPSM(address(susdsBase), 1_000_000e18 + 1);

        foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        skip(1 days);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.depositPSM(address(susdsBase), 500_000e18 - 3200 + 1);

        foreignController.depositPSM(address(susdsBase), 500_000e18 - 3200);
    }

}

contract ForeignControllerDepositTests is ForeignControllerPSMSuccessTestBase {

    function test_deposit_usds() external {
        bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

        // Get funds from mainnet to base
        deal(address(usdsBase), address(almProxy), 1_000_000e18);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 1_000_000e18,
            psmBalance       : 0,  // From seeding USDS
            proxyShares      : 0,
            totalShares      : 1e18,  // From seeding USDS
            totalAssets      : 1e18,  // From seeding USDS
            rateLimitKey     : key,
            currentRateLimit : 1_000_000e18
        });

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(usdsBase), 1_000_000e18);

        assertEq(shares, 1_000_000e18);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 0,
            psmBalance       : 1_000_000e18,
            proxyShares      : 1_000_000e18,
            totalShares      : 1_000_001e18,
            totalAssets      : 1_000_001e18,
            rateLimitKey     : key,
            currentRateLimit : 0
        });
    }

    function test_deposit_usdc() external {
        bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

        // Simulate planner moving funds to base, `deal` not working
        vm.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        usdcBase.transfer(address(almProxy), 1_000_000e6);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 1_000_000e6,
            psmBalance       : 1e6,
            proxyShares      : 0,
            totalShares      : 1e18,  // From seeding USDS
            totalAssets      : 1e18,  // From seeding USDS
            rateLimitKey     : key,
            currentRateLimit : 1_000_000e6
        });

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(usdcBase), 1_000_000e6);

        assertEq(shares, 1_000_000e18);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 0,
            psmBalance       : 1_000_001e6,
            proxyShares      : 1_000_000e18,
            totalShares      : 1_000_001e18,
            totalAssets      : 1_000_001e18,
            rateLimitKey     : key,
            currentRateLimit : 0
        });
    }

    function test_deposit_susds() external {
        bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

        // Rough conversion of $8m USDS to sUSDS
        deal(address(susdsBase), address(almProxy), 7_950_000e18);

        _assertState({
            token            : susdsBase,
            proxyBalance     : 7_950_000e18,
            psmBalance       : 0,
            proxyShares      : 0,
            totalShares      : 1e18,  // From seeding USDS
            totalAssets      : 1e18,  // From seeding USDS
            rateLimitKey     : key,
            currentRateLimit : 1_000_000e18
        });

        vm.startPrank(relayer);
        uint256 shares = foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        assertEq(shares, 1_007_021.913460737731511810e18);  // Sanity check conversion at fork block

        _assertState({
            token            : susdsBase,
            proxyBalance     : 6_950_000e18,  // Rounding
            psmBalance       : 1_000_000e18,
            proxyShares      : shares,
            totalShares      : 1e18 + shares,
            totalAssets      : 1e18 + shares,
            rateLimitKey     : key,
            currentRateLimit : 0
        });

        // Warp a minute past to ensure rounding doesn't affect getting to the max amount

        skip(2 days + 1 minutes);
        shares += foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        skip(2 days + 1 minutes);
        shares += foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        skip(2 days + 1 minutes);
        shares += foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        skip(2 days + 1 minutes);
        shares += foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        skip(2 days + 1 minutes);
        shares += foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        skip(2 days + 1 minutes);
        shares += foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        skip(2 days + 1 minutes);
        shares += foreignController.depositPSM(address(susdsBase), 950_000e18);

        _assertState({
            token            : susdsBase,
            proxyBalance     : 0,
            psmBalance       : 7_950_000e18,
            proxyShares      : shares,
            totalShares      : 1e18 + shares,
            totalAssets      : 8_025_193.158812994026660455e18,  // Hardcoded because assets appreciate which is complex to assert
            rateLimitKey     : key,
            currentRateLimit : 50_000e18
        });
    }

}

contract ForeignControllerWithdrawPSMFailureTests is ForeignControllerPSMSuccessTestBase {

    function test_withdrawPSM_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            foreignController.RELAYER()
        ));
        foreignController.withdrawPSM(address(usdsBase), 100e18);
    }

    function test_withdrawPSM_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.withdrawPSM(address(usdsBase), 100e18);
    }

}

contract ForeignControllerWithdrawTests is ForeignControllerPSMSuccessTestBase {

    function test_withdraw_usds() external {
        bytes32 withdrawKey = foreignController.LIMIT_PSM_WITHDRAW();

        deal(address(usdsBase), address(almProxy), 1_000_000e18);
        vm.prank(relayer);
        foreignController.depositPSM(address(usdsBase), 1_000_000e18);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 0,
            psmBalance       : 1_000_000e18,
            proxyShares      : 1_000_000e18,
            totalShares      : 1_000_001e18,
            totalAssets      : 1_000_001e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 1_000_000e18
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(usdsBase), 600_000e18);

        assertEq(amountWithdrawn, 600_000e18);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 600_000e18,
            psmBalance       : 400_000e18,
            proxyShares      : 400_000e18,
            totalShares      : 400_001e18,
            totalAssets      : 400_001e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 400_000e18
        });

        skip(1 days);

        bytes32 assetKey = RateLimitHelpers.makeAssetKey(withdrawKey, address(usdsBase));

        assertEq(rateLimits.getCurrentRateLimit(assetKey), 900_000e18 - 3200);

        vm.prank(relayer);
        amountWithdrawn = foreignController.withdrawPSM(address(usdsBase), 400_000e18);

        assertEq(amountWithdrawn, 400_000e18);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 1_000_000e18,
            psmBalance       : 0,
            proxyShares      : 0,
            totalShares      : 1e18,
            totalAssets      : 1e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 500_000e18 - 3200
        });
    }

    function test_withdraw_usdc() external {
        bytes32 withdrawKey = foreignController.LIMIT_PSM_WITHDRAW();

        // Simulate planner moving funds to base, `deal` not working
        vm.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        usdcBase.transfer(address(almProxy), 1_000_000e6);

        vm.prank(relayer);
        foreignController.depositPSM(address(usdcBase), 1_000_000e6);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 0,
            psmBalance       : 1_000_001e6,
            proxyShares      : 1_000_000e18,
            totalShares      : 1_000_001e18,
            totalAssets      : 1_000_001e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 1_000_000e6
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(usdcBase), 600_000e6);

        assertEq(amountWithdrawn, 600_000e6);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 600_000e6,
            psmBalance       : 400_001e6,
            proxyShares      : 400_000e18,
            totalShares      : 400_001e18,
            totalAssets      : 400_001e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 400_000e6
        });

        skip(1 days);

        bytes32 assetKey = RateLimitHelpers.makeAssetKey(withdrawKey, address(usdcBase));

        assertEq(rateLimits.getCurrentRateLimit(assetKey), 900_000e6 - 3200);

        vm.prank(relayer);
        amountWithdrawn = foreignController.withdrawPSM(address(usdcBase), 400_000e6);

        assertEq(amountWithdrawn, 400_000e6);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 1_000_000e6,
            psmBalance       : 1e6,
            proxyShares      : 0,
            totalShares      : 1e18,
            totalAssets      : 1e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 500_000e6 - 3200
        });
    }

    function test_withdraw_susds() external {
        bytes32 withdrawKey = foreignController.LIMIT_PSM_WITHDRAW();

        uint256 conversionRate1 = IRateProviderLike(psmBase.rateProvider()).getConversionRate();

        deal(address(susdsBase), address(almProxy), 1_000_000e18);

        vm.prank(relayer);
        foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        _assertState({
            token            : susdsBase,
            proxyBalance     : 0,
            psmBalance       : 1_000_000e18,
            proxyShares      : 1_000_000e18 * conversionRate1 / 1e27,
            totalShares      : 1_000_000e18 * conversionRate1 / 1e27 + 1e18,
            totalAssets      : 1_000_000e18 * conversionRate1 / 1e27 + 1e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 1_000_000e18
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(susdsBase), 600_000e18);

        assertEq(amountWithdrawn, 600_000e18);

        _assertState({
            token            : susdsBase,
            proxyBalance     : 600_000e18,
            psmBalance       : 400_000e18,
            proxyShares      : 400_000e18 * conversionRate1 / 1e27 - 1,         // Rounding
            totalShares      : 400_000e18 * conversionRate1 / 1e27 + 1e18 - 1,  // Rounding
            totalAssets      : 400_000e18 * conversionRate1 / 1e27 + 1e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 400_000e18
        });

        skip(1 days);

        bytes32 assetKey = RateLimitHelpers.makeAssetKey(withdrawKey, address(susdsBase));

        assertEq(rateLimits.getCurrentRateLimit(assetKey), 900_000e18 - 3200);

        vm.prank(relayer);
        amountWithdrawn = foreignController.withdrawPSM(address(susdsBase), 300_000e18);

        assertEq(amountWithdrawn, 300_000e18);

        _assertState({
            token            : susdsBase,
            proxyBalance     : 900_000e18,
            psmBalance       : 100_000e18,
            proxyShares      : 100_702.191216684984374424e18,  // Using spot check here instead of complex derivation
            totalShares      : 100_703.191216684984374424e18,
            totalAssets      : 100_720.567366306896358406e18,
            rateLimitKey     : withdrawKey,
            currentRateLimit : 600_000e18 - 3200
        });
    }

}
