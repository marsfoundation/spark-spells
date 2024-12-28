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

interface ISSRRateSource {
    function susds() external view returns (address);
}

interface IIRM {
    function RATE_SOURCE() external view returns (ISSRRateSource);
}

interface IRateSource {
    function getAPR() external view returns (uint256);
}

contract SparkEthereum_20250109Test is SparkTestBase {

    using DomainHelpers for *;

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0xC527A1B514796A6519f236dd906E73cab5aA2E71;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0xd957978711F705358dbE34B37D381a76E1555E28;
    address public constant OLD_STABLECOINS_INTEREST_RATE_STRATEGY = 0x4Da18457A76C355B74F9e4A944EcC882aAc64043;
    address public constant NEW_STABLECOINS_INTEREST_RATE_STRATEGY = 0xb7b734CF1F13652E930f8a604E8f837f85160174;

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
        pool.setUserUseReserveAsCollateral(Ethereum.WEETH, true);
        pool.borrow(Ethereum.DAI, 1e18, 2, 0, address(this));

        // Cannot borrow another asset
        vm.expectRevert(bytes('60'));  // ASSET_NOT_BORROWABLE_IN_ISOLATION
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

    function test_ETHEREUM_StablecoinUpdates() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore  = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        ReserveConfig memory usdcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDC');
        ReserveConfig memory usdtConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDT');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);
        assertEq(usdcConfigBefore.interestRateStrategy, OLD_STABLECOINS_INTEREST_RATE_STRATEGY);
        assertEq(usdtConfigBefore.interestRateStrategy, OLD_STABLECOINS_INTEREST_RATE_STRATEGY);

        IDefaultInterestRateStrategy prevIRM = IDefaultInterestRateStrategy(usdcConfigBefore.interestRateStrategy);
        uint256 currVarSlope1 = 0.11885440509995120663752e27;
        _validateInterestRateStrategy(
            address(prevIRM),
            OLD_STABLECOINS_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(prevIRM.ADDRESSES_PROVIDER()),
                optimalUsageRatio:             prevIRM.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: prevIRM.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          currVarSlope1,
                stableRateSlope1:              prevIRM.getStableRateSlope1(),
                stableRateSlope2:              prevIRM.getStableRateSlope2(),
                baseVariableBorrowRate:        prevIRM.getBaseVariableBorrowRate(),
                variableRateSlope1:            currVarSlope1,
                variableRateSlope2:            prevIRM.getVariableRateSlope2()
            })
        );

        executeAllPayloadsAndBridges();

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigAfter  = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');
        ReserveConfig memory usdcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDC');
        ReserveConfig memory usdtConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDT');

        address rateSource = address(IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE());
        address susds = ISSRRateSource(rateSource).susds();
        assertEq(susds, Ethereum.SUSDS);

        // Confirm all rate sources are the same
        assertEq(address(IIRM(usdcConfigAfter.interestRateStrategy).RATE_SOURCE()), rateSource);

        uint256 ssrApr = IRateSource(rateSource).getAPR();

        // Approx 12.5% APY
        assertEq(_getAPY(ssrApr), 0.124999999999999999980492118e27);

        uint256 expectedDaiBaseVariableBorrowRate = ssrApr + 0.0025e27;

        // Approx 12.75% APY (deviation due to addition of APR)
        assertEq(_getAPY(expectedDaiBaseVariableBorrowRate), 0.127816018545877080595039981e27);

        _validateInterestRateStrategy(
            daiConfigAfter.interestRateStrategy,
            NEW_DAI_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(IDefaultInterestRateStrategy(daiConfigAfter.interestRateStrategy).ADDRESSES_PROVIDER()),
                optimalUsageRatio:             1e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        expectedDaiBaseVariableBorrowRate,
                variableRateSlope1:            0,
                variableRateSlope2:            0
            })
        );

        // Note: the slope1 changes slightly due to the difference between APY and APR addition
        //       (11.5% APY + 1% APR != 12.5% APY + 0% APR)
        uint256 newVarSlope1 = 0.117783035876335945414896e27;
        _validateInterestRateStrategy(
            usdcConfigAfter.interestRateStrategy,
            NEW_STABLECOINS_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(prevIRM.ADDRESSES_PROVIDER()),
                optimalUsageRatio:             prevIRM.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: prevIRM.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          newVarSlope1,
                stableRateSlope1:              prevIRM.getStableRateSlope1(),
                stableRateSlope2:              prevIRM.getStableRateSlope2(),
                baseVariableBorrowRate:        prevIRM.getBaseVariableBorrowRate(),
                variableRateSlope1:            newVarSlope1,
                variableRateSlope2:            prevIRM.getVariableRateSlope2()
            })
        );
        assertEq(usdcConfigAfter.interestRateStrategy, usdtConfigAfter.interestRateStrategy);
    }

    function test_ETHEREUM_BASE_USDSBridging() public onChain(ChainIdUtils.Base()) {
        uint256 baseBalanceBefore = IERC20(Base.USDS).balanceOf(Base.ALM_PROXY);

        executeAllPayloadsAndBridges();

        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY), baseBalanceBefore + USDS_MINT_AMOUNT);
    }

    function test_ETHEREUM_BASE_PayloadExecution() public onChain(ChainIdUtils.Base()) {
        assertEq(IExecutor(Base.SPARK_EXECUTOR).actionsSetCount(), 2);

        executeAllPayloadsAndBridges();

        assertEq(IExecutor(Base.SPARK_EXECUTOR).actionsSetCount(), 3);
        IExecutor(Base.SPARK_EXECUTOR).execute(2);
    }

}
