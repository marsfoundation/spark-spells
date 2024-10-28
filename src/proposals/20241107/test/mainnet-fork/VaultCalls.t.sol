// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "./SparkEthereum_20241107TestBase.t.sol";

contract MainnetControllerMintUSDSTests is PostSpellExecutionTestBase {

    function test_mintUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            mainnetController.RELAYER()
        ));
        mainnetController.mintUSDS(1e18);
    }

}
