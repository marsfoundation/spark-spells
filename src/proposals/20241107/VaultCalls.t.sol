// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "./SparkEthereum_20241107TestBase.t.sol";

contract MainnetControllerMintUSDSTests is SparkEthereum_20241107TestBase {

    function test_first() public {
        // executePayload(payload);
    }

//     function test_mintUSDS_notRelayer() external {
//         vm.expectRevert(abi.encodeWithSignature(
//             "AccessControlUnauthorizedAccount(address,bytes32)",
//             address(this),
//             RELAYER
//         ));
//         mainnetController.mintUSDS(1e18);
//     }

//     function test_mintUSDS_frozen() external {
//         vm.prank(freezer);
//         mainnetController.freeze();

//         vm.prank(relayer);
//         vm.expectRevert("MainnetController/not-active");
//         mainnetController.mintUSDS(1e18);
//     }

//     function test_mintUSDS() external {
//         ( uint256 ink, uint256 art ) = dss.vat.urns(ilk, vault);
//         ( uint256 Art,,,, )          = dss.vat.ilks(ilk);

//         assertEq(dss.vat.dai(USDS_JOIN), VAT_DAI_USDS_JOIN);

//         assertEq(Art, 0);
//         assertEq(ink, INK);
//         assertEq(art, 0);

//         assertEq(usds.balanceOf(address(almProxy)), 0);
//         assertEq(usds.totalSupply(),                USDS_SUPPLY);

//         vm.prank(relayer);
//         mainnetController.mintUSDS(1e18);

//         ( ink, art ) = dss.vat.urns(ilk, vault);
//         ( Art,,,, )  = dss.vat.ilks(ilk);

//         assertEq(dss.vat.dai(USDS_JOIN), VAT_DAI_USDS_JOIN + 1e45);

//         assertEq(Art, 1e18);
//         assertEq(ink, INK);
//         assertEq(art, 1e18);

//         assertEq(usds.balanceOf(address(almProxy)), 1e18);
//         assertEq(usds.totalSupply(),                USDS_SUPPLY + 1e18);
//     }

//     function test_mintUSDS_rateLimited() external {
//         bytes32 key = mainnetController.LIMIT_USDS_MINT();
//         vm.startPrank(relayer);

//         assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e18);
//         assertEq(usds.balanceOf(address(almProxy)),   0);

//         mainnetController.mintUSDS(1_000_000e18);

//         assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);
//         assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18);

//         skip(1 hours);

//         assertEq(rateLimits.getCurrentRateLimit(key), 4_249_999.9999999999999984e18);
//         assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18);

//         mainnetController.mintUSDS(4_249_999.9999999999999984e18);

//         assertEq(rateLimits.getCurrentRateLimit(key), 0);
//         assertEq(usds.balanceOf(address(almProxy)),   5_249_999.9999999999999984e18);

//         vm.expectRevert("RateLimits/rate-limit-exceeded");
//         mainnetController.mintUSDS(1);

//         vm.stopPrank();
//     }

// }

// contract MainnetControllerBurnUSDSTests is ForkTestBase {

//     function test_burnUSDS_notRelayer() external {
//         vm.expectRevert(abi.encodeWithSignature(
//             "AccessControlUnauthorizedAccount(address,bytes32)",
//             address(this),
//             RELAYER
//         ));
//         mainnetController.burnUSDS(1e18);
//     }

//     function test_burnUSDS_frozen() external {
//         vm.prank(freezer);
//         mainnetController.freeze();

//         vm.prank(relayer);
//         vm.expectRevert("MainnetController/not-active");
//         mainnetController.burnUSDS(1e18);
//     }

//     function test_burnUSDS() external {
//         // Setup
//         vm.prank(relayer);
//         mainnetController.mintUSDS(1e18);

//         ( uint256 ink, uint256 art ) = dss.vat.urns(ilk, vault);
//         ( uint256 Art,,,, )          = dss.vat.ilks(ilk);

//         assertEq(dss.vat.dai(USDS_JOIN), VAT_DAI_USDS_JOIN + 1e45);

//         assertEq(Art, 1e18);
//         assertEq(ink, INK);
//         assertEq(art, 1e18);

//         assertEq(usds.balanceOf(address(almProxy)), 1e18);
//         assertEq(usds.totalSupply(),                USDS_SUPPLY + 1e18);

//         vm.prank(relayer);
//         mainnetController.burnUSDS(1e18);

//         ( ink, art ) = dss.vat.urns(ilk, vault);
//         ( Art,,,, )  = dss.vat.ilks(ilk);

//         assertEq(dss.vat.dai(USDS_JOIN), VAT_DAI_USDS_JOIN);

//         assertEq(Art, 0);
//         assertEq(ink, INK);
//         assertEq(art, 0);

//         assertEq(usds.balanceOf(address(almProxy)), 0);
//         assertEq(usds.totalSupply(),                USDS_SUPPLY);
//     }

//     function test_burnUSDS_rateLimited() external {
//         bytes32 key = mainnetController.LIMIT_USDS_MINT();
//         vm.startPrank(relayer);

//         assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e18);
//         assertEq(usds.balanceOf(address(almProxy)),   0);

//         mainnetController.mintUSDS(1_000_000e18);

//         assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);
//         assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18);

//         mainnetController.burnUSDS(500_000e18);

//         assertEq(rateLimits.getCurrentRateLimit(key), 4_500_000e18);
//         assertEq(usds.balanceOf(address(almProxy)),   500_000e18);

//         skip(4 hours);

//         assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e18);
//         assertEq(usds.balanceOf(address(almProxy)),   500_000e18);

//         mainnetController.burnUSDS(500_000e18);

//         assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e18);
//         assertEq(usds.balanceOf(address(almProxy)),   0);

//         vm.stopPrank();
//     }

}
