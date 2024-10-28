// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./SparkBase_20241107TestBase.t.sol";

// import { RateLimitHelpers } from 'lib/spark-alm-controller/src/RateLimitHelpers.sol';

// contract ForeignControllerPSMSuccessTestBase is PostSpellExecutionBaseTestBase {

//     function _assertState(
//         IERC20  token,
//         uint256 proxyBalance,
//         uint256 psmBalance,
//         uint256 proxyShares,
//         uint256 totalShares,
//         uint256 totalAssets,
//         bytes32 rateLimitKey,
//         uint256 currentRateLimit
//     )
//         internal view
//     {
//         address custodian = address(token) == address(usdcBase) ? pocket : address(psmBase);

//         assertEq(token.balanceOf(address(almProxy)),          proxyBalance);
//         assertEq(token.balanceOf(address(foreignController)), 0);  // Should always be zero
//         assertEq(token.balanceOf(custodian),                  psmBalance);

//         assertEq(psmBase.shares(address(almProxy)), proxyShares);
//         assertEq(psmBase.totalShares(),             totalShares);
//         assertEq(psmBase.totalAssets(),             totalAssets);

//         bytes32 assetKey = RateLimitHelpers.makeAssetKey(rateLimitKey, address(token));

//         assertEq(rateLimits.getCurrentRateLimit(assetKey), currentRateLimit);

//         // Should always be 0 before and after calls
//         assertEq(usdsBase.allowance(address(almProxy), address(psmBase)), 0);
//     }

// }


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

}

// contract ForeignControllerDepositTests is ForeignControllerPSMSuccessTestBase {

//     function test_deposit_usds() external {
//         bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

//         // NOTE: USDS deposits are not going to be rate limited for launch
//         bytes32 assetKey = RateLimitHelpers.makeAssetKey(key, address(usdsBase));

//         vm.prank(SPARK_EXECUTOR);
//         rateLimits.setUnlimitedRateLimitData(assetKey);

//         deal(address(usdsBase), address(almProxy), 100e18);

//         _assertState({
//             token            : usdsBase,
//             proxyBalance     : 100e18,
//             psmBalance       : 1e18,  // From seeding USDS
//             proxyShares      : 0,
//             totalShares      : 1e18,  // From seeding USDS
//             totalAssets      : 1e18,  // From seeding USDS
//             rateLimitKey     : key,
//             currentRateLimit : type(uint256).max
//         });

//         vm.prank(relayer);
//         uint256 shares = foreignController.depositPSM(address(usdsBase), 100e18);

//         assertEq(shares, 100e18);

//         _assertState({
//             token            : usdsBase,
//             proxyBalance     : 0,
//             psmBalance       : 101e18,
//             proxyShares      : 100e18,
//             totalShares      : 101e18,
//             totalAssets      : 101e18,
//             rateLimitKey     : key,
//             currentRateLimit : type(uint256).max
//         });
//     }

//     function test_deposit_usdc() external {
//         bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

//         deal(address(usdcBase), address(almProxy), 100e6);

//         _assertState({
//             token            : usdcBase,
//             proxyBalance     : 100e6,
//             psmBalance       : 0,
//             proxyShares      : 0,
//             totalShares      : 1e18,  // From seeding USDS
//             totalAssets      : 1e18,  // From seeding USDS
//             rateLimitKey     : key,
//             currentRateLimit : 5_000_000e6
//         });

//         vm.prank(relayer);
//         uint256 shares = foreignController.depositPSM(address(usdcBase), 100e6);

//         assertEq(shares, 100e18);

//         _assertState({
//             token            : usdcBase,
//             proxyBalance     : 0,
//             psmBalance       : 100e6,
//             proxyShares      : 100e18,
//             totalShares      : 101e18,
//             totalAssets      : 101e18,
//             rateLimitKey     : key,
//             currentRateLimit : 4_999_900e6
//         });
//     }

//     function test_deposit_susds() external {
//         bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

//         // NOTE: sUSDS deposits are not going to be rate limited for launch
//         bytes32 assetKey = RateLimitHelpers.makeAssetKey(key, address(susdsBase));

//         vm.prank(SPARK_EXECUTOR);
//         rateLimits.setUnlimitedRateLimitData(assetKey);

//         deal(address(susdsBase), address(almProxy), 100e18);

//         _assertState({
//             token            : susdsBase,
//             proxyBalance     : 100e18,
//             psmBalance       : 0,
//             proxyShares      : 0,
//             totalShares      : 1e18,  // From seeding USDS
//             totalAssets      : 1e18,  // From seeding USDS
//             rateLimitKey     : key,
//             currentRateLimit : type(uint256).max
//         });

//         vm.prank(relayer);
//         uint256 shares = foreignController.depositPSM(address(susdsBase), 100e18);

//         assertEq(shares, 100.343092065533568746e18);  // Sanity check conversion at fork block

//         _assertState({
//             token            : susdsBase,
//             proxyBalance     : 0,
//             psmBalance       : 100e18,
//             proxyShares      : shares,
//             totalShares      : 1e18 + shares,
//             totalAssets      : 1e18 + shares,
//             rateLimitKey     : key,
//             currentRateLimit : type(uint256).max
//         });
//     }

// }

// contract ForeignControllerWithdrawPSMFailureTests is ForkTestBase {

//     function test_withdrawPSM_notRelayer() external {
//         vm.expectRevert(abi.encodeWithSignature(
//             "AccessControlUnauthorizedAccount(address,bytes32)",
//             address(this),
//             RELAYER
//         ));
//         foreignController.withdrawPSM(address(usdsBase), 100e18);
//     }

//     function test_withdrawPSM_frozen() external {
//         vm.prank(freezer);
//         foreignController.freeze();

//         vm.prank(relayer);
//         vm.expectRevert("ForeignController/not-active");
//         foreignController.withdrawPSM(address(usdsBase), 100e18);
//     }

// }

// contract ForeignControllerWithdrawTests is ForeignControllerPSMSuccessTestBase {

//     function test_withdraw_usds() external {
//         bytes32 depositKey  = foreignController.LIMIT_PSM_DEPOSIT();
//         bytes32 withdrawKey = foreignController.LIMIT_PSM_WITHDRAW();

//         // NOTE: USDS deposits and withdrawals are not going to be rate limited for launch
//         bytes32 depositAssetKey  = RateLimitHelpers.makeAssetKey(depositKey,  address(usdsBase));
//         bytes32 withdrawAssetKey = RateLimitHelpers.makeAssetKey(withdrawKey, address(usdsBase));

//         vm.startPrank(SPARK_EXECUTOR);
//         rateLimits.setUnlimitedRateLimitData(depositAssetKey);
//         rateLimits.setUnlimitedRateLimitData(withdrawAssetKey);
//         vm.stopPrank();

//         deal(address(usdsBase), address(almProxy), 100e18);
//         vm.prank(relayer);
//         foreignController.depositPSM(address(usdsBase), 100e18);

//         _assertState({
//             token            : usdsBase,
//             proxyBalance     : 0,
//             psmBalance       : 101e18,
//             proxyShares      : 100e18,
//             totalShares      : 101e18,
//             totalAssets      : 101e18,
//             rateLimitKey     : withdrawKey,
//             currentRateLimit : type(uint256).max
//         });

//         vm.prank(relayer);
//         uint256 amountWithdrawn = foreignController.withdrawPSM(address(usdsBase), 100e18);

//         assertEq(amountWithdrawn, 100e18);

//         _assertState({
//             token            : usdsBase,
//             proxyBalance     : 100e18,
//             psmBalance       : 1e18,  // From seeding USDS
//             proxyShares      : 0,
//             totalShares      : 1e18,  // From seeding USDS
//             totalAssets      : 1e18,  // From seeding USDS
//             rateLimitKey     : withdrawKey,
//             currentRateLimit : type(uint256).max
//         });
//     }

//     function test_withdraw_usdc() external {
//         bytes32 key = foreignController.LIMIT_PSM_WITHDRAW();

//         deal(address(usdcBase), address(almProxy), 100e6);
//         vm.prank(relayer);
//         foreignController.depositPSM(address(usdcBase), 100e6);

//         _assertState({
//             token            : usdcBase,
//             proxyBalance     : 0,
//             psmBalance       : 100e6,
//             proxyShares      : 100e18,
//             totalShares      : 101e18,
//             totalAssets      : 101e18,
//             rateLimitKey     : key,
//             currentRateLimit : 5_000_000e6
//         });

//         vm.prank(relayer);
//         uint256 amountWithdrawn = foreignController.withdrawPSM(address(usdcBase), 100e6);

//         assertEq(amountWithdrawn, 100e6);

//         _assertState({
//             token            : usdcBase,
//             proxyBalance     : 100e6,
//             psmBalance       : 0,
//             proxyShares      : 0,
//             totalShares      : 1e18,  // From seeding USDS
//             totalAssets      : 1e18,  // From seeding USDS
//             rateLimitKey     : key,
//             currentRateLimit : 4_999_900e6
//         });
//     }

//     function test_withdraw_susds() external {
//         bytes32 depositKey  = foreignController.LIMIT_PSM_DEPOSIT();
//         bytes32 withdrawKey = foreignController.LIMIT_PSM_WITHDRAW();

//         // NOTE: sUSDS deposits and withdrawals are not going to be rate limited for launch
//         bytes32 depositAssetKey  = RateLimitHelpers.makeAssetKey(depositKey,  address(susdsBase));
//         bytes32 withdrawAssetKey = RateLimitHelpers.makeAssetKey(withdrawKey, address(susdsBase));

//         vm.startPrank(SPARK_EXECUTOR);
//         rateLimits.setUnlimitedRateLimitData(depositAssetKey);
//         rateLimits.setUnlimitedRateLimitData(withdrawAssetKey);
//         vm.stopPrank();

//         deal(address(susdsBase), address(almProxy), 100e18);
//         vm.prank(relayer);
//         uint256 shares = foreignController.depositPSM(address(susdsBase), 100e18);

//         assertEq(shares, 100.343092065533568746e18);  // Sanity check conversion at fork block

//         _assertState({
//             token            : susdsBase,
//             proxyBalance     : 0,
//             psmBalance       : 100e18,
//             proxyShares      : shares,
//             totalShares      : 1e18 + shares,
//             totalAssets      : 1e18 + shares,
//             rateLimitKey     : withdrawKey,
//             currentRateLimit : type(uint256).max
//         });

//         vm.prank(relayer);
//         uint256 amountWithdrawn = foreignController.withdrawPSM(address(susdsBase), 100e18);

//         assertEq(amountWithdrawn, 100e18 - 1);  // Rounding

//         _assertState({
//             token            : susdsBase,
//             proxyBalance     : 100e18 - 1,  // Rounding
//             psmBalance       : 1,           // Rounding
//             proxyShares      : 0,
//             totalShares      : 1e18,      // From seeding USDS
//             totalAssets      : 1e18 + 1,  // From seeding USDS, rounding
//             rateLimitKey     : withdrawKey,
//             currentRateLimit : type(uint256).max
//         });
//     }

// }
