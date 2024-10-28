// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./SparkEthereum_20241107TestBase.t.sol";

interface IPSMLike {
    function buf() external view returns (uint256);
    function line() external view returns (uint256);
    function bud(address) external view returns (uint256);
    function pocket() external view returns (address);
    function kiss(address) external;
    function rush() external view returns (uint256);
}

contract MainnetControllerSwapUSDSToUSDCFailureTests is PostSpellExecutionTestBase {

    function test_swapUSDSToUSDC_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            mainnetController.RELAYER()
        ));
        mainnetController.swapUSDSToUSDC(1e6);
    }

    function test_swapUSDSToUSDC_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.swapUSDSToUSDC(1e6);
    }

}

contract MainnetControllerSwapUSDSToUSDCTests is PostSpellExecutionTestBase {

    function test_swapUSDSToUSDC() external {
        vm.prank(relayer);
        mainnetController.mintUSDS(1_000_000e18);

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         USDS_SUPPLY + 1_000_000e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(POCKET)),            USDC_BAL_PSM);

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
        assertEq(dai.allowance(address(almProxy),  PSM),            0);

        vm.prank(relayer);
        mainnetController.swapUSDSToUSDC(1_000_000e6);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         USDS_SUPPLY);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM + 1_000_000e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY + 1_000_000e18);

        assertEq(usdc.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(POCKET)),            USDC_BAL_PSM - 1_000_000e6);

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
        assertEq(dai.allowance(address(almProxy),  PSM),            0);
    }

    function test_swapUSDSToUSDC_rateLimited() external {
        bytes32 key = mainnetController.LIMIT_USDS_TO_USDC();
        vm.startPrank(relayer);

        mainnetController.mintUSDS(1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 1_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   0);

        mainnetController.swapUSDSToUSDC(400_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 600_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   600_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   400_000e6);

        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 600_000e6 + uint256(500_000e6) / 24 - 133);
        assertEq(usds.balanceOf(address(almProxy)),   600_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   400_000e6);

        mainnetController.swapUSDSToUSDC(600_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), uint256(500_000e6) / 24 - 133);
        assertEq(usds.balanceOf(address(almProxy)),   0);
        assertEq(usdc.balanceOf(address(almProxy)),   1_000_000e6);

        skip(23 hours);

        // Rate limit goes up to 500k + 100 (3200 rounding error)
        assertEq(rateLimits.getCurrentRateLimit(key), uint256(500_000e6) - 3200);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.swapUSDSToUSDC(uint256(500_000e6) - 3200 + 1);

        vm.expectRevert("Usds/insufficient-balance");
        mainnetController.swapUSDSToUSDC(uint256(500_000e6) - 3200);
    }

}

// contract MainnetControllerSwapUSDCToUSDSFailureTests is PostSpellExecutionTestBase {

//     function test_swapUSDCToUSDS_notRelayer() external {
//         vm.expectRevert(abi.encodeWithSignature(
//             "AccessControlUnauthorizedAccount(address,bytes32)",
//             address(this),
//             mainnetController.RELAYER()
//         ));
//         mainnetController.swapUSDCToUSDS(1e6);
//     }

//     function test_swapUSDCToUSDS_frozen() external {
//         vm.prank(freezer);
//         mainnetController.freeze();

//         vm.prank(relayer);
//         vm.expectRevert("MainnetController/not-active");
//         mainnetController.swapUSDCToUSDS(1e6);
//     }

//     function test_swapUSDCToUSDS_incompleteFillBoundary() external {
//         // The line is just over 2.1 billion, this condition will allow DAI to get minted to get to
//         // 2 billion in Art, and then another fill to get to the `line`.
//         deal(address(usdc), address(POCKET), 2_000_000_000e6);

//         uint256 fillAmount = psm.rush();

//         assertEq(fillAmount, 3_008_396.9118e18); // Only first fill amount

//         // NOTE: Art == dai here because rate is 1 for PSM ilk
//         ( uint256 Art,,, uint256 line, ) = dss.vat.ilks(PSM_ILK);

//         assertEq(Art,              2_396_991_603.0882e18);
//         assertEq(Art + fillAmount, 2_400_000_000e18);
//         assertEq(line / 1e27,      2_796_991_603.0882e18);

//         // The first fill increases the Art to 2.4 billion and the USDC balance of the PSM to roughly 2.4 billion.
//         // For the second fill, the USDC balance + BUFFER option is over 2.8 billion so it instead fills to the line
//         // which is 2.796 billion.
//         uint256 expectedFillAmount2 = line / 1e27 - 2_400_000_000e18;

//         assertEq(expectedFillAmount2, 396_991_603.0882e18);

//         // Max amount of DAI that can be swapped, converted to USDC precision
//         uint256 maxSwapAmount = (DAI_BAL_PSM + fillAmount + expectedFillAmount2) / 1e12;

//         assertEq(maxSwapAmount, 813_630_294.354574e6);

//         deal(address(usdc), address(almProxy), maxSwapAmount + 1);

//         vm.startPrank(relayer);
//         vm.expectRevert("DssLitePsm/nothing-to-fill");
//         mainnetController.swapUSDCToUSDS(maxSwapAmount + 1);

//         mainnetController.swapUSDCToUSDS(maxSwapAmount);

//         assertEq(usds.balanceOf(address(almProxy)), maxSwapAmount * 1e12);

//         ( Art,,,, ) = dss.vat.ilks(PSM_ILK);

//         // Art has now been filled to the debt ceiling and there is no DAI left in the PSM.
//         assertEq(Art, line / 1e27);
//         assertEq(Art, 2_796_991_603.0882e18);

//         assertEq(dai.balanceOf(address(PSM)), 0);
//     }

// }

// contract MainnetControllerSwapUSDCToUSDSTests is PostSpellExecutionTestBase {

//     event Fill(uint256 wad);

//     function test_swapUSDCToUSDS() external {
//         deal(address(usdc), address(almProxy), 1e6);

//         assertEq(usds.balanceOf(address(almProxy)),          0);
//         assertEq(usds.balanceOf(address(mainnetController)), 0);
//         assertEq(usds.totalSupply(),                         USDS_SUPPLY);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY);

//         assertEq(usdc.balanceOf(address(almProxy)),          1e6);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.balanceOf(address(POCKET)),            USDC_BAL_PSM);

//         assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
//         assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
//         assertEq(dai.allowance(address(almProxy),  PSM),            0);

//         vm.prank(relayer);
//         mainnetController.swapUSDCToUSDS(1e6);

//         assertEq(usds.balanceOf(address(almProxy)),          1e18);
//         assertEq(usds.balanceOf(address(mainnetController)), 0);
//         assertEq(usds.totalSupply(),                         USDS_SUPPLY + 1e18);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM - 1e18);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY - 1e18);

//         assertEq(usdc.balanceOf(address(almProxy)),          0);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.balanceOf(address(POCKET)),            USDC_BAL_PSM + 1e6);

//         assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
//         assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
//         assertEq(dai.allowance(address(almProxy),  PSM),            0);
//     }

//     function test_swapUSDCToUSDS_exactBalanceNoRefill() external {
//         uint256 swapAmount = DAI_BAL_PSM / 1e12;

//         deal(address(usdc), address(almProxy), swapAmount);

//         assertEq(usds.balanceOf(address(almProxy)),          0);
//         assertEq(usds.balanceOf(address(mainnetController)), 0);
//         assertEq(usds.totalSupply(),                         USDS_SUPPLY);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY);

//         assertEq(usdc.balanceOf(address(almProxy)),          swapAmount);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.balanceOf(address(POCKET)),            USDC_BAL_PSM);

//         assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
//         assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
//         assertEq(dai.allowance(address(almProxy),  PSM),            0);

//         ( uint256 Art1,,,, ) = dss.vat.ilks(PSM_ILK);

//         vm.prank(relayer);
//         mainnetController.swapUSDCToUSDS(swapAmount);

//         ( uint256 Art2,,,, ) = dss.vat.ilks(PSM_ILK);

//         assertEq(Art1, Art2);  // Fill was not called on exact amount

//         assertEq(usds.balanceOf(address(almProxy)),          DAI_BAL_PSM);  // Drain PSM
//         assertEq(usds.balanceOf(address(mainnetController)), 0);
//         assertEq(usds.totalSupply(),                         USDS_SUPPLY + DAI_BAL_PSM);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      0);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY - DAI_BAL_PSM);

//         assertEq(usdc.balanceOf(address(almProxy)),          0);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.balanceOf(address(POCKET)),            USDC_BAL_PSM + swapAmount);

//         assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
//         assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
//         assertEq(dai.allowance(address(almProxy),  PSM),            0);
//     }

//     function test_swapUSDCToUSDS_partialRefill() external {
//         assertEq(DAI_BAL_PSM, 413_630_294.354574e18);

//         // PSM is not fillable at current fork so need to deal USDC
//         uint256 fillAmount = psm.rush();

//         assertEq(fillAmount, 0);

//         ( uint256 Art,,, uint256 line, ) = dss.vat.ilks(PSM_ILK);

//         // Art is less than line, but USDC balance needs to increase to allow minting
//         assertEq(usdc.balanceOf(POCKET) * 1e12 + IPSMLike(PSM).buf(), 2_383_361_309.129139e18);
//         assertEq(Art,                                             2_396_991_603.0882e18);
//         assertEq(line / 1e27,                                     2_796_991_603.0882e18);

//         // This will bring USDC balance + BUFFER over Art
//         deal(address(usdc), address(POCKET), 2_000_000_000e6);

//         assertEq(usdc.balanceOf(POCKET) * 1e12 + IPSMLike(PSM).buf(), 2_400_000_000e18);
//         assertEq(Art,                                             2_396_991_603.0882e18);
//         assertEq(line / 1e27,                                     2_796_991_603.0882e18);

//         ( Art,,, line, ) = dss.vat.ilks(PSM_ILK);

//         fillAmount = psm.rush();

//         assertEq(fillAmount, 3_008_396.9118e18);
//         assertEq(fillAmount, 2_400_000_000e18 - Art);

//         // Higher than balance of DAI, less than fillAmount + balance
//         deal(address(usdc), address(almProxy), 415_000_000e6);

//         assertEq(usds.balanceOf(address(almProxy)),          0);
//         assertEq(usds.balanceOf(address(mainnetController)), 0);
//         assertEq(usds.totalSupply(),                         USDS_SUPPLY);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY);

//         assertEq(usdc.balanceOf(address(almProxy)),          415_000_000e6);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.balanceOf(address(POCKET)),            2_000_000_000e6);

//         assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
//         assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
//         assertEq(dai.allowance(address(almProxy),  PSM),            0);

//         vm.prank(relayer);
//         vm.expectEmit(PSM);
//         emit Fill(fillAmount);
//         mainnetController.swapUSDCToUSDS(415_000_000e6);

//         ( Art,,,, ) = dss.vat.ilks(PSM_ILK);

//         // Amount minted brings Art to usdc balance + BUFFER
//         assertEq(Art, 2_400_000_000e18);

//         assertEq(usds.balanceOf(address(almProxy)),          415_000_000e18);
//         assertEq(usds.balanceOf(address(mainnetController)), 0);
//         assertEq(usds.totalSupply(),                         USDS_SUPPLY + 415_000_000e18);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM + fillAmount - 415_000_000e18);
//         assertEq(dai.balanceOf(address(PSM)),      1_638_691.266374e18);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY + fillAmount - 415_000_000e18);

//         assertEq(usdc.balanceOf(address(almProxy)),          0);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.balanceOf(address(POCKET)),            2_415_000_000e6);  // 2 billion + 415 million

//         assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
//         assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
//         assertEq(dai.allowance(address(almProxy),  PSM),            0);
//     }

//     function test_swapUSDCToUSDS_multipleRefills() external {
//         assertEq(DAI_BAL_PSM, 413_630_294.354574e18);

//         // PSM is not fillable at current fork so need to deal USDC
//         uint256 fillAmount = psm.rush();

//         assertEq(fillAmount, 0);

//         ( uint256 Art,,, uint256 line, ) = dss.vat.ilks(PSM_ILK);

//         // Art is less than line, but USDC balance needs to increase to allow minting
//         assertEq(usdc.balanceOf(POCKET) * 1e12 + IPSMLike(PSM).buf(), 2_383_361_309.129139e18);
//         assertEq(Art,                                             2_396_991_603.0882e18);
//         assertEq(line / 1e27,                                     2_796_991_603.0882e18);

//         // This will bring USDC balance + BUFFER over Art
//         deal(address(usdc), address(POCKET), 2_000_000_000e6);

//         assertEq(usdc.balanceOf(POCKET) * 1e12 + IPSMLike(PSM).buf(), 2_400_000_000e18);
//         assertEq(Art,                                             2_396_991_603.0882e18);
//         assertEq(line / 1e27,                                     2_796_991_603.0882e18);

//         ( Art,,, line, ) = dss.vat.ilks(PSM_ILK);

//         fillAmount = psm.rush();

//         assertEq(fillAmount, 3_008_396.9118e18);
//         assertEq(fillAmount, 2_400_000_000e18 - Art);  // NOTE: This is just the first fill amount

//         // The first fill increases the Art to 2.4 billion and the USDC balance of the PSM to roughly 2.4 billion.
//         // For the second fill, the USDC balance + BUFFER option is over 2.8 billion so it instead fills to the line
//         // which is 2.796 billion.
//         uint256 expectedFillAmount2 = line / 1e27 - 2_400_000_000e18;

//         assertEq(expectedFillAmount2, 396_991_603.0882e18);

//         deal(address(usdc), address(almProxy), 500_000_000e6);  // Higher than balance of DAI + fillAmount

//         assertEq(usds.balanceOf(address(almProxy)),          0);
//         assertEq(usds.balanceOf(address(mainnetController)), 0);
//         assertEq(usds.totalSupply(),                         USDS_SUPPLY);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY);

//         assertEq(usdc.balanceOf(address(almProxy)),          500_000_000e6);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.balanceOf(address(POCKET)),            2_000_000_000e6);

//         assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
//         assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
//         assertEq(dai.allowance(address(almProxy),  PSM),            0);

//         assertEq(Art + fillAmount + expectedFillAmount2, line / 1e27);  // Two fills will increase Art to the debt ceiling

//         vm.prank(relayer);
//         vm.expectEmit(PSM);
//         emit Fill(fillAmount);
//         emit Fill(expectedFillAmount2);
//         mainnetController.swapUSDCToUSDS(500_000_000e6);

//         ( Art,,,, ) = dss.vat.ilks(PSM_ILK);

//         // Art has now been filled to the debt ceiling.
//         assertEq(Art, line / 1e27);
//         assertEq(Art, 2_796_991_603.0882e18);

//         assertEq(usds.balanceOf(address(almProxy)),          500_000_000e18);
//         assertEq(usds.balanceOf(address(mainnetController)), 0);
//         assertEq(usds.totalSupply(),                         USDS_SUPPLY + 500_000_000e18);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM + fillAmount + expectedFillAmount2 - 500_000_000e18);
//         assertEq(dai.balanceOf(address(PSM)),      313_630_294.354574e18);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY + fillAmount + expectedFillAmount2 - 500_000_000e18);

//         assertEq(usdc.balanceOf(address(almProxy)),          0);
//         assertEq(usdc.balanceOf(address(mainnetController)), 0);
//         assertEq(usdc.balanceOf(address(POCKET)),            2_500_000_000e6);  // 2 billion + 500 millions

//         assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
//         assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
//         assertEq(dai.allowance(address(almProxy),  PSM),            0);
//     }

//     function test_swapUSDCToUSDS_rateLimited() external {
//         bytes32 key = mainnetController.LIMIT_USDS_TO_USDC();
//         vm.startPrank(relayer);

//         mainnetController.mintUSDS(5_000_000e18);

//         mainnetController.swapUSDSToUSDC(1_000_000e6);

//         assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e6);
//         assertEq(usds.balanceOf(address(almProxy)),   4_000_000e18);
//         assertEq(usdc.balanceOf(address(almProxy)),   1_000_000e6);

//         mainnetController.swapUSDCToUSDS(400_000e6);

//         assertEq(rateLimits.getCurrentRateLimit(key), 4_400_000e6);
//         assertEq(usds.balanceOf(address(almProxy)),   4_400_000e18);
//         assertEq(usdc.balanceOf(address(almProxy)),   600_000e6);

//         skip(4 hours);

//         assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e6);
//         assertEq(usds.balanceOf(address(almProxy)),   4_400_000e18);
//         assertEq(usdc.balanceOf(address(almProxy)),   600_000e6);

//         mainnetController.swapUSDCToUSDS(600_000e6);

//         assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e6);
//         assertEq(usds.balanceOf(address(almProxy)),   5_000_000e18);
//         assertEq(usdc.balanceOf(address(almProxy)),   0);

//         vm.stopPrank();
//     }

//     function testFuzz_swapUSDCToUSDS(uint256 swapAmount) external {
//         swapAmount = _bound(swapAmount, 1e6, 1_000_000_000e6);

//         deal(address(usdc), address(almProxy), swapAmount);

//         uint256 usdsBalanceBefore = usds.balanceOf(address(almProxy));

//         // NOTE: Doing a low-level call here because if the full amount can't be swapped, it should revert
//         vm.prank(relayer);
//         ( bool success, ) = address(mainnetController).call(
//             abi.encodeWithSignature("swapUSDCToUSDS(uint256)", swapAmount)
//         );

//         if (success) {
//             assertEq(usds.balanceOf(address(almProxy)), usdsBalanceBefore + swapAmount * 1e12);
//         }
//     }

// }

