// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IACLManager } from 'aave-v3-core/contracts/interfaces/IACLManager.sol';

import { ICapAutomator } from '../../interfaces/ICapAutomator.sol';

import { EngineFlags, IEngine,  Rates, SparkPayloadEthereum } from '../../SparkPayloadEthereum.sol';

/**
 * @title  March 06, 2024 Spark Ethereum Proposal - Activate Cap Automator, update ETH eMode, update interest rates for WETH and rETH, update collateral parameters for multiple markets
 * @author Phoenix Labs
 * @dev    This proposal adds the Cap Automator as a risk admin to the Pool and sets supply and borrow cap configs for rETH, sDAI, USDC, USDT, WBTC, WETH and wstETH markets;
 *         sets ETH eMode to 93% ltv, 95% liqThreshold and 101% liqBonus; updates rETH baseVariableBorrowRate to 0.25% and WETH variableRateSlope1 to 2.8%;
 *         updates ltv, liqThreshold and liqBonus for rETH, sDAI, WBTC, WETH and wstETH markets.
 * Forum:  https://forum.makerdao.com/t/feb-22-2024-proposed-changes-to-sparklend-for-upcoming-spell/23739
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
            92_00,
            93_00,
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
            ltv:            79_00,
            liqThreshold:   80_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[1] = IEngine.CollateralUpdate({
            asset:          SDAI,
            ltv:            79_00,
            liqThreshold:   80_00,
            liqBonus:       5_00,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[2] = IEngine.CollateralUpdate({
            asset:          WBTC,
            ltv:            74_00,
            liqThreshold:   EngineFlags.KEEP_CURRENT,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[3] = IEngine.CollateralUpdate({
            asset:          WETH,
            ltv:            82_00,
            liqThreshold:   83_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        collateralUpdates[4] = IEngine.CollateralUpdate({
            asset:          WSTETH,
            ltv:            79_00,
            liqThreshold:   80_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return collateralUpdates;
    }

    function rateStrategiesUpdates()
        public view override returns (IEngine.RateStrategyUpdate[] memory)
    {
        IEngine.RateStrategyUpdate[] memory ratesUpdate = new IEngine.RateStrategyUpdate[](2);
        Rates.RateStrategyParams memory rethParams = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(RETH);

        rethParams.baseVariableBorrowRate = _bpsToRay(25);

        ratesUpdate[0] = IEngine.RateStrategyUpdate({
            asset:  RETH,
            params: rethParams
        });

        Rates.RateStrategyParams memory wethParams = LISTING_ENGINE
            .RATE_STRATEGIES_FACTORY()
            .getStrategyDataOfAsset(WETH);

        wethParams.variableRateSlope1 = _bpsToRay(2_80);

        ratesUpdate[1] = IEngine.RateStrategyUpdate({
            asset:  WETH,
            params: wethParams
        });

        return ratesUpdate;
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
