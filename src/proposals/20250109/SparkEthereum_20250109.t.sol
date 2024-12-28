// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import 'src/SparkTestBase.sol';

import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { Base } from 'spark-address-registry/Base.sol';

import { Domain, DomainHelpers } from "xchain-helpers/testing/Domain.sol";

import { ForeignController } from 'spark-alm-controller/src/ForeignController.sol';
import { IExecutor }         from 'spark-gov-relay/src/interfaces/IExecutor.sol';

import { ChainIdUtils } from 'src/libraries/ChainId.sol';

interface DssAutoLineLike {
    function setIlk(bytes32 ilk, uint256 line, uint256 gap, uint256 ttl) external;
    function exec(bytes32 ilk) external;
}

contract SparkEthereum_20250109Test is SparkTestBase {

    using DomainHelpers for *;

    address internal constant PT_SUSDE_24OCT2024_PRICE_FEED = 0xaE4750d0813B5E37A51f7629beedd72AF1f9cA35;
    address internal constant PT_SUSDE_24OCT2024            = 0xAE5099C39f023C91d3dd55244CAFB36225B0850E;
    address internal constant PT_SUSDE_26DEC2024_PRICE_FEED = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address internal constant PT_SUSDE_26DEC2024            = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;
    address internal constant PT_SUSDE_27MAR2025_PRICE_FEED = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address internal constant PT_SUSDE_27MAR2025            = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;
    address internal constant PT_SUSDE_29MAY2025_PRICE_FEED = 0xE84f7e0a890e5e57d0beEa2c8716dDf0c9846B4A;
    address internal constant PT_SUSDE_29MAY2025            = 0xb7de5dFCb74d25c2f21841fbd6230355C50d9308;

    address internal constant AUTO_LINE     = 0xC7Bdd1F2B16447dcf3dE045C4a039A60EC2f0ba3;
    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-SPARK-A";

    uint256 internal constant USDS_MINT_AMOUNT = 99_000_000e18;

    constructor() {
        id = '20250109';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock: 21502540,
            baseForkBlock:    24309280,
            gnosisForkBlock:  37691338
        });
        deployPayloads();

        // mock Sky increase max line to 1b, which will be executed as part of this spell
        vm.prank(Ethereum.PAUSE_PROXY);
        DssAutoLineLike(AUTO_LINE).setIlk(ALLOCATOR_ILK, 1_000_000_000e45, 100_000_000e45, 24 hours);
        DssAutoLineLike(AUTO_LINE).exec(ALLOCATOR_ILK);
    }

    function test_ETHEREUM_WBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory wbtcConfig         = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold, 60_00);

        executeAllPayloadsAndBridges();

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        wbtcConfig.liquidationThreshold        = 55_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
    }

    function test_ETHEREUM_CBBTCChanges() public {
        _assertSupplyCapConfig(Ethereum.CBBTC, 3_000, 500, 12 hours);

        executeAllPayloadsAndBridges();

        _assertSupplyCapConfig(Ethereum.CBBTC, 10_000, 500, 12 hours);
    }

    function test_ETHEREUM_WSTETHChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory wstethConfig       = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');

        IDefaultInterestRateStrategy prevIRM = IDefaultInterestRateStrategy(wstethConfig.interestRateStrategy);
        _validateInterestRateStrategy(
            address(prevIRM),
            address(prevIRM),
            InterestStrategyValues({
                addressesProvider:             address(prevIRM.ADDRESSES_PROVIDER()),
                optimalUsageRatio:             0.45e27,
                optimalStableToTotalDebtRatio: prevIRM.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.045e27,
                stableRateSlope1:              prevIRM.getStableRateSlope1(),
                stableRateSlope2:              prevIRM.getStableRateSlope2(),
                baseVariableBorrowRate:        0.0025e27,
                variableRateSlope1:            0.045e27,
                variableRateSlope2:            0.8e27
            })
        );

        assertEq(wstethConfig.reserveFactor, 15_00);

        _assertSupplyCapConfig(Ethereum.WSTETH, 1_200_000, 50_000, 12 hours);
        _assertBorrowCapConfig(Ethereum.WSTETH, 100_000, 5_000, 12 hours);

        executeAllPayloadsAndBridges();

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        wstethConfig.reserveFactor        = 30_00;
        wstethConfig.interestRateStrategy = _findReserveConfigBySymbol(allConfigsAfter, 'wstETH').interestRateStrategy;

        _validateReserveConfig(wstethConfig, allConfigsAfter);
        _validateInterestRateStrategy(
            wstethConfig.interestRateStrategy,
            wstethConfig.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(prevIRM.ADDRESSES_PROVIDER()),
                optimalUsageRatio:             0.7e27,
                optimalStableToTotalDebtRatio: prevIRM.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.02e27,
                stableRateSlope1:              prevIRM.getStableRateSlope1(),
                stableRateSlope2:              prevIRM.getStableRateSlope2(),
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.02e27,
                variableRateSlope2:            3e27
            })
        );

        _assertSupplyCapConfig(Ethereum.WSTETH, 2_000_000, 50_000, 12 hours);
        _assertBorrowCapConfig(Ethereum.WSTETH, 500_000, 5_000, 12 hours);
    }

    function test_ETHEREUM_WEETHChanges() public {
        deal(Ethereum.WEETH, address(this), 10e18);
        IERC20(Ethereum.WEETH).approve(Ethereum.POOL, 10e18);
        pool.supply(Ethereum.WEETH, 10e18, address(this), 0);
        pool.borrow(Ethereum.DAI, 1e18, 2, 0, address(this));

        // Cannot borrow another asset
        vm.expectRevert(bytes(34));
        pool.borrow(Ethereum.WETH, 1e18, 2, 0, address(this));

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory weethConfig        = _findReserveConfigBySymbol(allConfigsBefore, 'weETH');

        assertEq(weethConfig.debtCeiling, 200_000_000_00);

        executeAllPayloadsAndBridges();

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        weethConfig.debtCeiling                = 0;

        _validateReserveConfig(weethConfig, allConfigsAfter);

        // Can now borrow another asset
        pool.borrow(Ethereum.WETH, 1e18, 2, 0, address(this));
    }

    function test_ETHEREUM_MorphoSupplyCapUpdates() public {
        MarketParams memory usde945 =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: Ethereum.USDE,
            oracle:          Ethereum.MORPHO_USDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.945e18
        });
        MarketParams memory usde77 =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: Ethereum.USDE,
            oracle:          Ethereum.MORPHO_USDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.77e18
        });
        MarketParams memory susde945 =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: Ethereum.SUSDE,
            oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.945e18
        });
        MarketParams memory susde77 =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: Ethereum.SUSDE,
            oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.77e18
        });
        MarketParams memory ptsusdeoct =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_24OCT2024,
            oracle:          PT_SUSDE_24OCT2024_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        });
        MarketParams memory ptsusdedec =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_26DEC2024,
            oracle:          PT_SUSDE_26DEC2024_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });
        MarketParams memory ptsusdemar =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_27MAR2025,
            oracle:          PT_SUSDE_27MAR2025_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });
        MarketParams memory ptsusdemay =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_29MAY2025,
            oracle:          PT_SUSDE_29MAY2025_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        _assertMorphoCap(usde945,    10_000_000e18);
        _assertMorphoCap(usde77,     1_000_000_000e18);
        _assertMorphoCap(susde945,   10_000_000e18);
        _assertMorphoCap(susde77,    1_000_000_000e18);
        _assertMorphoCap(ptsusdeoct, 100_000_000e18);
        _assertMorphoCap(ptsusdedec, 250_000_000e18);
        _assertMorphoCap(ptsusdemar, 400_000_000e18);
        _assertMorphoCap(ptsusdemay, 0);

        executeAllPayloadsAndBridges();

        _assertMorphoCap(usde945,    0);
        _assertMorphoCap(usde77,     0);
        _assertMorphoCap(susde945,   0);
        _assertMorphoCap(susde77,    0);
        _assertMorphoCap(ptsusdeoct, 0);
        _assertMorphoCap(ptsusdedec, 0);
        _assertMorphoCap(ptsusdemar, 400_000_000e18, 500_000_000e18);
        _assertMorphoCap(ptsusdemay, 0,              200_000_000e18);

        skip(1 days);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptsusdemar);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptsusdemay);
        
        _assertMorphoCap(ptsusdemar, 500_000_000e18);
        _assertMorphoCap(ptsusdemay, 200_000_000e18);
    }

    function testBridging() external {
        uint256 baseBalanceBefore = 123496652107156694;
        uint256 SUSDSShares       = IERC4626(Ethereum.SUSDS).convertToShares(USDS_MINT_AMOUNT);

        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), baseBalanceBefore);

        executeAllPayloadsAndBridges();

        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), baseBalanceBefore + SUSDSShares);
    }

    function testE2ELiquidityProvisioningToBase() external {
        ForeignController controller = ForeignController(Base.ALM_CONTROLLER);
        address relayer              = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

        uint256 baseALMBalanceBefore = 123496652107156694;
        uint256 basePSMBalanceBefore = 7561335102296991391227534;
        uint256 SUSDSShares          = IERC4626(Ethereum.SUSDS).convertToShares(USDS_MINT_AMOUNT);
        uint256 depositAmount        = 1_000_000e18;

        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.PSM3), basePSMBalanceBefore);

        // insufficient ALM_PROXY balance prevents the deposit
        vm.prank(relayer);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        controller.depositPSM(Base.SUSDS, depositAmount);

        chainSpellMetadata[ChainIdUtils.Ethereum()].domain.selectFork();

        executeAllPayloadsAndBridges();
        
        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), baseALMBalanceBefore + SUSDSShares);
        // after funds are bridged, liquidity can be provisioned to the PSM
        vm.prank(relayer);
        controller.depositPSM(Base.SUSDS, depositAmount);
        assertEq(
          IERC20(Base.SUSDS).balanceOf(Base.PSM3),
          basePSMBalanceBefore + depositAmount
        );
        assertEq(
          IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY),
          baseALMBalanceBefore + SUSDSShares - depositAmount
        );
    }

    function testBasePayloadExecution() external {
        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        assertEq(IExecutor(Base.SPARK_EXECUTOR).actionsSetCount(), 1);

        executeAllPayloadsAndBridges();

        assertEq(IExecutor(Base.SPARK_EXECUTOR).actionsSetCount(), 2);
        IExecutor(Base.SPARK_EXECUTOR).execute(1);
    }

}
