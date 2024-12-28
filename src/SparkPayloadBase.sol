// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Base } from 'spark-address-registry/Base.sol';

import { SparkLiquidityLayerHelpers } from './libraries/SparkLiquidityLayerHelpers.sol';

/**
 * @dev Base smart contract for Base Chain.
 * @author Phoenix Labs
 */
abstract contract SparkPayloadBase {

    function _onboardAaveToken(address token, uint256 depositMax, uint256 depositSlope) internal {
        SparkLiquidityLayerHelpers.onboardAaveToken(
            Base.ALM_RATE_LIMITS,
            token,
            depositMax,
            depositSlope
        );
    }

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        SparkLiquidityLayerHelpers.onboardERC4626Vault(
            Base.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

    function _activateMorphoVault(address vault, bool createIdleMarket) internal {
        SparkLiquidityLayerHelpers.activateMorphoVault(
            vault,
            Base.ALM_RELAYER,
            createIdleMarket
        );
    }

}
