// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IERC20 }   from 'forge-std/interfaces/IERC20.sol';
import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { IAToken } from "aave-v3-origin/src/core/contracts/interfaces/IAToken.sol";

import { IMetaMorpho, Id }       from "metamorpho/interfaces/IMetaMorpho.sol";
import { MarketParamsLib }       from "morpho-blue/src/libraries/MarketParamsLib.sol";
import { IMorpho, MarketParams } from "morpho-blue/src/interfaces/IMorpho.sol";

import { RateLimitHelpers, RateLimitData } from "spark-alm-controller/src/RateLimitHelpers.sol";

/**
 * @notice Helper functions for Spark Liquidity Layer
 */
library SparkLiquidityLayerHelpers {

    // This is the same on all chains
    address private constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    bytes32 private constant LIMIT_4626_DEPOSIT  = keccak256("LIMIT_4626_DEPOSIT");
    bytes32 private constant LIMIT_4626_WITHDRAW = keccak256("LIMIT_4626_WITHDRAW");
    bytes32 private constant LIMIT_AAVE_DEPOSIT  = keccak256("LIMIT_AAVE_DEPOSIT");
    bytes32 private constant LIMIT_AAVE_WITHDRAW = keccak256("LIMIT_AAVE_WITHDRAW");

    /**
     * @notice Onboard an Aave token
     * @dev This will set the deposit to the given numbers with
     *      the withdraw limit set to unlimited.
     */
    function onboardAaveToken(
        address rateLimits,
        address token,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        IERC20 underlying = IERC20(IAToken(token).UNDERLYING_ASSET_ADDRESS());

        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                LIMIT_AAVE_DEPOSIT,
                token
            ),
            rateLimits,
            RateLimitData({
                maxAmount : depositMax,
                slope     : depositSlope
            }),
            "atokenDepositLimit",
            underlying.decimals()
        );
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                LIMIT_AAVE_WITHDRAW,
                token
            ),
            rateLimits,
            RateLimitData({
                maxAmount : type(uint256).max,
                slope     : 0
            }),
            "atokenWithdrawLimit",
            underlying.decimals()
        );
    }

    /**
     * @notice Onboard an ERC4626 vault
     * @dev This will set the deposit to the given numbers with
     *      the withdraw limit set to unlimited.
     */
    function onboardERC4626Vault(
        address rateLimits,
        address vault,
        uint256 depositMax,
        uint256 depositSlope
    ) internal {
        IERC20 asset = IERC20(IERC4626(vault).asset());

        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                LIMIT_4626_DEPOSIT,
                vault
            ),
            rateLimits,
            RateLimitData({
                maxAmount : depositMax,
                slope     : depositSlope
            }),
            "vaultDepositLimit",
            asset.decimals()
        );
        RateLimitHelpers.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                LIMIT_4626_WITHDRAW,
                vault
            ),
            rateLimits,
            RateLimitData({
                maxAmount : type(uint256).max,
                slope     : 0
            }),
            "vaultWithdrawLimit",
            asset.decimals()
        );
    }

    function morphoIdleMarket(
        address asset
    ) internal pure returns (MarketParams memory) {
        return MarketParams({
            loanToken:       asset,
            collateralToken: address(0),
            oracle:          address(0),
            irm:             address(0),
            lltv:            0
        });
    }

    /**
     * @notice Activate a Morpho Vault
     * @dev This will do the following:
     *      - Add the idle market for the underlying asset with unlimited size
     *      - Add the relayer as an allocator
     */
    function activateMorphoVault(
        address vault,
        address relayer,
        bool createIdleMarket
    ) internal {
        IERC20 asset = IERC20(IERC4626(vault).asset());
        MarketParams memory idleMarket = morphoIdleMarket(address(asset));

        if (createIdleMarket) {
            IMorpho(MORPHO).createMarket(
                idleMarket
            );
        }
        
        IMetaMorpho(vault).setIsAllocator(
            relayer,
            true
        );
        IMetaMorpho(vault).submitCap(
            idleMarket,
            type(uint184).max
        );
    }

}
