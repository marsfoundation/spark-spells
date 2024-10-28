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

contract MainnetControllerSwapUSDCToUSDSFailureTests is PostSpellExecutionTestBase {

    function test_swapUSDCToUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            mainnetController.RELAYER()
        ));
        mainnetController.swapUSDCToUSDS(1e6);
    }

    function test_swapUSDCToUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.swapUSDCToUSDS(1e6);
    }

    // NOTE: Skipped test because this isn't possible with mainnet configuration
    // function test_swapUSDCToUSDS_incompleteFillBoundary() external {}

}

contract MainnetControllerSwapUSDCToUSDSTests is PostSpellExecutionTestBase {

    function setUp() override public {
        super.setUp();

        vm.startPrank(relayer);
        mainnetController.mintUSDS(1_000_000e18);
        mainnetController.swapUSDSToUSDC(1_000_000e6);
        vm.stopPrank();

        // Overwrite mainnet params
        DAI_BAL_PSM  = dai.balanceOf(PSM);
        DAI_SUPPLY   = dai.totalSupply();
        USDC_BAL_PSM = usdc.balanceOf(POCKET);
        USDS_SUPPLY  = usds.totalSupply();
    }

    function test_swapUSDCToUSDS() external {
        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         USDS_SUPPLY);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(usdc.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(POCKET)),            USDC_BAL_PSM);

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
        assertEq(dai.allowance(address(almProxy),  PSM),            0);

        vm.prank(relayer);
        mainnetController.swapUSDCToUSDS(1_000_000e6);

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         USDS_SUPPLY + 1_000_000e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM - 1_000_000e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY - 1_000_000e18);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(POCKET)),            USDC_BAL_PSM + 1_000_000e6);

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), DAI_USDS),       0);
        assertEq(dai.allowance(address(almProxy),  PSM),            0);
    }

    // NOTE: Skipped tests because this isn't possible with mainnet configuration
    // function test_swapUSDCToUSDS_exactBalanceNoRefill() external {}
    // function test_swapUSDCToUSDS_partialRefill() external {}
    // function test_swapUSDCToUSDS_multipleRefills() external {}

    function test_swapUSDCToUSDS_rateLimited() external {
        bytes32 key = mainnetController.LIMIT_USDS_TO_USDC();
        vm.startPrank(relayer);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);
        assertEq(usds.balanceOf(address(almProxy)),   0);
        assertEq(usdc.balanceOf(address(almProxy)),   1_000_000e6);

        mainnetController.swapUSDCToUSDS(400_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 400_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   400_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   600_000e6);

        skip(24 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 900_000e6 - 3200);  // Rounding
        assertEq(usds.balanceOf(address(almProxy)),   400_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   600_000e6);

        mainnetController.swapUSDCToUSDS(600_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 1_000_000e6);  // Goes back to max
        assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   0);
    }

}

