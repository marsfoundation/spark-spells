// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IACLManager } from 'aave-v3-core/contracts/interfaces/IACLManager.sol';

import { ICapAutomator } from '../../interfaces/ICapAutomator.sol';

import { SparkPayloadEthereum, IEngine, EngineFlags } from '../../SparkPayloadEthereum.sol';

/**
 * @title  March 06, 2024 Spark Ethereum Proposal - Activate Cap Automator
 * @author Phoenix Labs
 * @dev    This proposal activates the Cap Automator
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkEthereum_20240306 is SparkPayloadEthereum {

    address internal constant ACL_MANAGER   = 0xdA135Cd78A086025BcdC87B038a1C462032b510C;
    address internal constant CAP_AUTOMATOR = 0x2276f52afba7Cf2525fd0a050DF464AC8532d0ef;

    address internal constant RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address internal constant SDAI   = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address internal constant USDC   = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT   = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant WBTC   = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant WETH   = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    function _preExecute()
        internal override
    {
        LISTING_ENGINE.POOL_CONFIGURATOR().setEModeCategory(
            1,
            93_00,
            95_00,
            101_00,
            address(0),
            'ETH'
        );
    }

    function collateralsUpdates()
        public pure override returns (IEngine.CollateralUpdate[] memory)
    {
        IEngine.CollateralUpdate[] memory collateralUpdates = new IEngine.CollateralUpdate[](5);

        collateralUpdates[0] = IEngine.CollateralUpdate({
            asset:          RETH,
            ltv:            74_50,
            liqThreshold:   77_00,
            liqBonus:       7_50,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[1] = IEngine.CollateralUpdate({
            asset:          SDAI,
            ltv:            77_00,
            liqThreshold:   80_00,
            liqBonus:       4_50,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[2] = IEngine.CollateralUpdate({
            asset:          WBTC,
            ltv:            73_00,
            liqThreshold:   78_00,
            liqBonus:       5_00,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[3] = IEngine.CollateralUpdate({
            asset:          WETH,
            ltv:            80_50,
            liqThreshold:   83_00,
            liqBonus:       5_00,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[4] = IEngine.CollateralUpdate({
            asset:          WSTETH,
            ltv:            78_50,
            liqThreshold:   81_00,
            liqBonus:       6_00,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return collateralUpdates;
    }

    function _postExecute()
        internal override
    {
        IACLManager(ACL_MANAGER).addRiskAdmin(CAP_AUTOMATOR);

        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: RETH, max: 80_000, gap: 10_000, increaseCooldown: 12 hours});
        ICapAutomator(CAP_AUTOMATOR).setBorrowCapConfig({asset: RETH, max: 2_400,  gap: 100,    increaseCooldown: 12 hours});

        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: SDAI, max: 1_000_000_000, gap: 50_000_000, increaseCooldown: 12 hours});

        ICapAutomator(CAP_AUTOMATOR).setBorrowCapConfig({asset: USDC, max: 57_000_000, gap: 6_000_000, increaseCooldown: 12 hours});

        ICapAutomator(CAP_AUTOMATOR).setBorrowCapConfig({asset: USDT, max: 28_500_000, gap: 3_000_000, increaseCooldown: 12 hours});

        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: WBTC, max: 5_000, gap: 500, increaseCooldown: 12 hours});
        ICapAutomator(CAP_AUTOMATOR).setBorrowCapConfig({asset: WBTC, max: 2_000, gap: 100, increaseCooldown: 12 hours});

        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: WETH, max: 2_000_000, gap: 150_000, increaseCooldown: 12 hours});
        ICapAutomator(CAP_AUTOMATOR).setBorrowCapConfig({asset: WETH, max: 1_000_000, gap: 10_000,  increaseCooldown: 12 hours});

        ICapAutomator(CAP_AUTOMATOR).setSupplyCapConfig({asset: WSTETH, max: 1_200_000, gap: 50_000, increaseCooldown: 12 hours});
        ICapAutomator(CAP_AUTOMATOR).setBorrowCapConfig({asset: WSTETH, max: 3_000,     gap: 100,    increaseCooldown: 12 hours});
    }

}
