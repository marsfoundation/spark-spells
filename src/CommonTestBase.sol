// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5 <0.9.0;

import 'forge-std/StdJson.sol';
import 'forge-std/Test.sol';
import {IERC20} from './interfaces/IERC20.sol';
import {AaveV2EthereumAssets} from 'aave-address-book/AaveV2Ethereum.sol';
import {AaveV3OptimismAssets} from 'aave-address-book/AaveV3Optimism.sol';

library ChainIds {
    uint256 internal constant MAINNET = 1;
    uint256 internal constant OPTIMISM = 10;
    uint256 internal constant POLYGON = 137;
    uint256 internal constant FANTOM = 250;
    uint256 internal constant METIS = 1088;
    uint256 internal constant ARBITRUM = 42161;
    uint256 internal constant AVALANCHE = 43114;
    uint256 internal constant HARMONY = 1666600000;
  }

contract CommonTestBase is Test {
  using stdJson for string;

  address public constant ETH_MOCK_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  address public constant EOA = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

  address public constant LDO_MAINNET  = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
  address public constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  /**
   * @notice deal doesn't support amounts stored in a script right now.
   * This function patches deal to mock and transfer funds instead.
   * @param asset the asset to deal
   * @param user the user to deal to
   * @param amount the amount to deal
   * @return bool true if the caller has changed due to prank usage
   */
  function _patchedDeal(address asset, address user, uint256 amount) internal returns (bool) {
    if (block.chainid == ChainIds.MAINNET) {
      // GUSD
      if (asset == AaveV2EthereumAssets.GUSD_UNDERLYING) {
        vm.startPrank(0x22FFDA6813f4F34C520bf36E5Ea01167bC9DF159);
        IERC20(asset).transfer(user, amount);
        return true;
      }
      // LDO
      if (asset == LDO_MAINNET) {
        vm.startPrank(0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c);
        IERC20(asset).transfer(user, amount);
        return true;
      }
      // SNX
      if (asset == AaveV2EthereumAssets.SNX_UNDERLYING) {
        vm.startPrank(0xAc86855865CbF31c8f9FBB68C749AD5Bd72802e3);
        IERC20(asset).transfer(user, amount);
        return true;
      }
      // sUSD
      if (asset == AaveV2EthereumAssets.sUSD_UNDERLYING) {
        vm.startPrank(0x99F4176EE457afedFfCB1839c7aB7A030a5e4A92);
        IERC20(asset).transfer(user, amount);
        return true;
      }
      // stETH
      if (asset == AaveV2EthereumAssets.stETH_UNDERLYING) {
        vm.startPrank(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        IERC20(asset).transfer(user, amount);
        return true;
      }
      // USDC
      if (asset == USDC_MAINNET) {
        vm.startPrank(0x28C6c06298d514Db089934071355E5743bf21d60);
        IERC20(asset).transfer(user, amount);
        return true;
      }
    }
    if (block.chainid == ChainIds.OPTIMISM) {
      // sUSD
      if (asset == AaveV3OptimismAssets.sUSD_UNDERLYING) {
        vm.startPrank(AaveV3OptimismAssets.sUSD_A_TOKEN);
        IERC20(asset).transfer(user, amount);
        return true;
      }
    }
    return false;
  }

  /**
   * Patched version of deal
   * @param asset to deal
   * @param user to deal to
   * @param amount to deal
   */
  function deal2(address asset, address user, uint256 amount) internal {
    bool patched = _patchedDeal(asset, user, amount);
    vm.stopPrank();
    if (!patched) {
      deal(asset, user, amount);
    }
  }

  /**
   * @dev generates the diff between two reports
   */
  function diffReports(string memory reportBefore, string memory reportAfter) internal {
    string memory outPath = string(
      abi.encodePacked('./diffs/', reportBefore, '_', reportAfter, '.md')
    );
    string memory beforePath = string(abi.encodePacked('./reports/', reportBefore, '.json'));
    string memory afterPath = string(abi.encodePacked('./reports/', reportAfter, '.json'));

    string[] memory inputs = new string[](7);
    inputs[0] = 'npx';
    inputs[1] = '@marsfoundation/aave-cli';
    inputs[2] = 'diff-snapshots';
    inputs[3] = beforePath;
    inputs[4] = afterPath;
    inputs[5] = '-o';
    inputs[6] = outPath;
    vm.ffi(inputs);
  }

  /**
   * @dev forwards time by x blocks
   */
  function _skipBlocks(uint128 blocks) internal {
    vm.roll(block.number + blocks);
    vm.warp(block.timestamp + blocks * 12); // assuming a block is around 12seconds
  }

  function _isInUint256Array(
    uint256[] memory haystack,
    uint256 needle
  ) internal pure returns (bool) {
    for (uint256 i = 0; i < haystack.length; i++) {
      if (haystack[i] == needle) return true;
    }
    return false;
  }

  function _isInAddressArray(
    address[] memory haystack,
    address needle
  ) internal pure returns (bool) {
    for (uint256 i = 0; i < haystack.length; i++) {
      if (haystack[i] == needle) return true;
    }
    return false;
  }
}
