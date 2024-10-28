// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./SparkEthereum_20241107TestBase.t.sol";

contract SUSDSTestBase is PostSpellExecutionTestBase {

    uint256 SUSDS_CONVERTED_ASSETS;
    uint256 SUSDS_CONVERTED_SHARES;

    uint256 SUSDS_TOTAL_ASSETS;
    uint256 SUSDS_TOTAL_SUPPLY;

    uint256 SUSDS_DRIP_AMOUNT;

    function setUp() override public {
        super.setUp();

        SUSDS_CONVERTED_ASSETS = susds.convertToAssets(1_000_000e18);
        SUSDS_CONVERTED_SHARES = susds.convertToShares(1_000_000e18);

        SUSDS_TOTAL_ASSETS = susds.totalAssets();
        SUSDS_TOTAL_SUPPLY = susds.totalSupply();
    }

}

contract MainnetControllerDepositToSUSDSFailureTests is SUSDSTestBase {

    function test_depositToSUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            mainnetController.RELAYER()
        ));
        mainnetController.depositToSUSDS(1_000_000e18);
    }

    function test_depositToSUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.depositToSUSDS(1_000_000e18);
    }

}

contract MainnetControllerDepositToSUSDSTests is SUSDSTestBase {

    function test_depositToSUSDS() external {
        vm.prank(relayer);
        mainnetController.mintUSDS(1_000_000e18);

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             USDS_BAL_SUSDS);

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)),  type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)),  0);

        assertEq(susds.totalSupply(),                SUSDS_TOTAL_SUPPLY);
        assertEq(susds.totalAssets(),                SUSDS_TOTAL_ASSETS);
        assertEq(susds.balanceOf(address(almProxy)), 0);

        vm.prank(relayer);
        uint256 shares = mainnetController.depositToSUSDS(1_000_000e18);

        assertEq(shares, SUSDS_CONVERTED_SHARES);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             USDS_BAL_SUSDS + SUSDS_DRIP_AMOUNT + 1_000_000e18);

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)), 0);

        assertEq(susds.totalSupply(),                SUSDS_TOTAL_SUPPLY + shares);
        assertEq(susds.totalAssets(),                SUSDS_TOTAL_ASSETS + 1_000_000e18);
        assertEq(susds.balanceOf(address(almProxy)), SUSDS_CONVERTED_SHARES);
    }

}

contract MainnetControllerWithdrawFromSUSDSFailureTests is SUSDSTestBase {

    function test_withdrawFromSUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            mainnetController.RELAYER()
        ));
        mainnetController.withdrawFromSUSDS(1_000_000e18);
    }

    function test_withdrawFromSUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.withdrawFromSUSDS(1_000_000e18);
    }

}

contract MainnetControllerWithdrawFromSUSDSTests is SUSDSTestBase {

    function test_withdrawFromSUSDS() external {
        vm.startPrank(relayer);
        mainnetController.mintUSDS(1_000_000e18);
        mainnetController.depositToSUSDS(1_000_000e18);
        vm.stopPrank();

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             USDS_BAL_SUSDS + SUSDS_DRIP_AMOUNT + 1_000_000e18);

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)), 0);

        assertEq(susds.totalSupply(),                SUSDS_TOTAL_SUPPLY + SUSDS_CONVERTED_SHARES);
        assertEq(susds.totalAssets(),                SUSDS_TOTAL_ASSETS + 1_000_000e18);
        assertEq(susds.balanceOf(address(almProxy)), SUSDS_CONVERTED_SHARES);

        // Max available with rounding
        vm.prank(relayer);
        uint256 shares = mainnetController.withdrawFromSUSDS(1_000_000e18 - 1);  // Rounding

        assertEq(shares, SUSDS_CONVERTED_SHARES);

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18 - 1);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             USDS_BAL_SUSDS + SUSDS_DRIP_AMOUNT + 1);  // Rounding

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)),  0);

        assertEq(susds.totalSupply(),                SUSDS_TOTAL_SUPPLY);
        assertEq(susds.totalAssets(),                SUSDS_TOTAL_ASSETS);
        assertEq(susds.balanceOf(address(almProxy)), 0);
    }

}

contract MainnetControllerRedeemFromSUSDSFailureTests is SUSDSTestBase {

    function test_redeemFromSUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            mainnetController.RELAYER()
        ));
        mainnetController.redeemFromSUSDS(1_000_000e18);
    }

    function test_redeemFromSUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.redeemFromSUSDS(1_000_000e18);
    }

}


contract MainnetControllerRedeemFromSUSDSTests is SUSDSTestBase {

    function test_redeemFromSUSDS() external {
        vm.startPrank(relayer);
        mainnetController.mintUSDS(1_000_000e18);
        mainnetController.depositToSUSDS(1_000_000e18);
        vm.stopPrank();

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             USDS_BAL_SUSDS + SUSDS_DRIP_AMOUNT + 1_000_000e18);

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)),  0);

        assertEq(susds.totalSupply(),                SUSDS_TOTAL_SUPPLY + SUSDS_CONVERTED_SHARES);
        assertEq(susds.totalAssets(),                SUSDS_TOTAL_ASSETS + 1_000_000e18);
        assertEq(susds.balanceOf(address(almProxy)), SUSDS_CONVERTED_SHARES);

        vm.prank(relayer);
        uint256 assets = mainnetController.redeemFromSUSDS(SUSDS_CONVERTED_SHARES);

        assertEq(assets, 1_000_000e18 - 1);  // Rounding

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18 - 1);  // Rounding
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             USDS_BAL_SUSDS + SUSDS_DRIP_AMOUNT + 1);  // Rounding

        assertEq(usds.allowance(address(BUFFER),   address(VAULT)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)), 0);

        assertEq(susds.totalSupply(),                SUSDS_TOTAL_SUPPLY);
        assertEq(susds.totalAssets(),                SUSDS_TOTAL_ASSETS);
        assertEq(susds.balanceOf(address(almProxy)), 0);
    }

}


