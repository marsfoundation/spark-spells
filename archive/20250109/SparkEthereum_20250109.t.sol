// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import 'src/SparkTestBase.sol';

import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { Base } from 'spark-address-registry/Base.sol';

import { DomainHelpers } from "xchain-helpers/testing/Domain.sol";
import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { IALMProxy }         from 'spark-alm-controller/src/interfaces/IALMProxy.sol';
import { IRateLimits }       from 'spark-alm-controller/src/interfaces/IRateLimits.sol';
import { MainnetController } from 'spark-alm-controller/src/MainnetController.sol';
import { ForeignController } from 'spark-alm-controller/src/ForeignController.sol';
import { RateLimitHelpers }  from 'spark-alm-controller/src/RateLimitHelpers.sol';

import { IMorpho, MarketAllocation, MarketParams } from 'metamorpho/interfaces/IMetaMorpho.sol';

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

interface IMorphoChainlinkOracle {
    function price() external view returns (uint256);
}

interface IPendlePT {
    function expiry() external view returns (uint256);
}

interface IEthenaMinter {
    function setCooldownDuration(uint24 duration) external;
    error OperationNotAllowed();
}

contract SparkEthereum_20250109Test is SparkTestBase {

    using DomainHelpers for *;

    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // --- Ethereum Addresses ---

    address internal constant NEW_ALM_CONTROLLER = 0x5cf73FDb7057E436A6eEaDFAd27E45E7ab6E431e;

    address internal constant OLD_DAI_INTEREST_RATE_STRATEGY = 0xC527A1B514796A6519f236dd906E73cab5aA2E71;
    address internal constant NEW_DAI_INTEREST_RATE_STRATEGY = 0xd957978711F705358dbE34B37D381a76E1555E28;
    address internal constant OLD_STABLECOINS_INTEREST_RATE_STRATEGY = 0x4Da18457A76C355B74F9e4A944EcC882aAc64043;
    address internal constant NEW_STABLECOINS_INTEREST_RATE_STRATEGY = 0xb7b734CF1F13652E930f8a604E8f837f85160174;

    address internal constant PT_SUSDE_24OCT2024_PRICE_FEED = 0xaE4750d0813B5E37A51f7629beedd72AF1f9cA35;
    address internal constant PT_SUSDE_24OCT2024            = 0xAE5099C39f023C91d3dd55244CAFB36225B0850E;
    address internal constant PT_SUSDE_26DEC2024_PRICE_FEED = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address internal constant PT_SUSDE_26DEC2024            = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;
    address internal constant PT_SUSDE_27MAR2025_PRICE_FEED = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address internal constant PT_SUSDE_27MAR2025            = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;
    address internal constant PT_SUSDE_29MAY2025_PRICE_FEED = 0xE84f7e0a890e5e57d0beEa2c8716dDf0c9846B4A;
    address internal constant PT_SUSDE_29MAY2025            = 0xb7de5dFCb74d25c2f21841fbd6230355C50d9308;
    uint256 internal constant PT_SUSDE_29MAY2025_YIELD      = 0.25e18;

    address internal constant ATOKEN_USDS = 0x32a6268f9Ba3642Dda7892aDd74f1D34469A4259;
    address internal constant ATOKEN_USDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    address internal constant AUTO_LINE     = 0xC7Bdd1F2B16447dcf3dE045C4a039A60EC2f0ba3;
    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-SPARK-A";

    address internal constant ETHENA_OWNER = 0x3B0AAf6e6fCd4a7cEEf8c92C32DFeA9E64dC1862;

    // --- Base Addresses ---

    uint256 internal constant USDS_MINT_AMOUNT = 99_000_000e18;

    address internal constant BASE_NEW_ALM_CONTROLLER = 0x5F032555353f3A1D16aA6A4ADE0B35b369da0440;

    address internal constant BASE_CBBTC              = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant BASE_CBBTC_USDC_ORACLE  = 0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9;
    address internal constant BASE_MORPHO_DEFAULT_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    address internal constant BASE_ATOKEN_USDC = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB;

    address internal constant BASE_MORPHO_SPARK_USDC = 0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A;

    constructor() {
        id = '20250109';
    }

    function setUp() public {
        setupDomains({
            mainnetForkBlock: 21566972,
            baseForkBlock:    24697931,
            gnosisForkBlock:  37691338
        });
        chainSpellMetadata[ChainIdUtils.Ethereum()].payload = 0x7fb2967cDC6816Dc508f35C5A6CB035C8B6507Ec;
        chainSpellMetadata[ChainIdUtils.Base()].payload     = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;

        // mock Sky increase max line to 1b, which will be executed as part of this spell
        vm.prank(Ethereum.PAUSE_PROXY);
        DssAutoLineLike(AUTO_LINE).setIlk(ALLOCATOR_ILK, 1_000_000_000e45, 100_000_000e45, 24 hours);
        DssAutoLineLike(AUTO_LINE).exec(ALLOCATOR_ILK);
    }

    function test_ETHEREUM_WBTCChanges() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory wbtcConfig         = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold, 60_00);

        executeAllPayloadsAndBridges();

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        wbtcConfig.liquidationThreshold        = 55_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
    }

    function test_ETHEREUM_CBBTCChanges() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        
        _assertSupplyCapConfig(Ethereum.CBBTC, 3_000, 500, 12 hours);

        executeAllPayloadsAndBridges();

        _assertSupplyCapConfig(Ethereum.CBBTC, 10_000, 500, 12 hours);
    }

    function test_ETHEREUM_WSTETHChanges() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        
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
        assertNotEq(wstethConfig.interestRateStrategy, address(prevIRM));

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
                variableRateSlope2:            2e27
            })
        );

        _assertSupplyCapConfig(Ethereum.WSTETH, 2_000_000, 50_000, 12 hours);
        _assertBorrowCapConfig(Ethereum.WSTETH, 1_000_000, 10_000, 12 hours);
    }

    function test_ETHEREUM_WEETHChanges() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        
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

    function test_ETHEREUM_MorphoSupplyCapUpdates() public onChain(ChainIdUtils.Ethereum()) {
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

        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, usde945,    10_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, usde77,     1_000_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, susde945,   10_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, susde77,    1_000_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdeoct, 100_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdedec, 250_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdemar, 400_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdemay, 0);

        executeAllPayloadsAndBridges();

        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, usde945,    0);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, usde77,     0);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, susde945,   0);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, susde77,    0);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdeoct, 0);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdedec, 0);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdemar, 400_000_000e18, 500_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdemay, 0,              200_000_000e18);

        skip(1 days);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptsusdemar);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptsusdemay);
        
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdemar, 500_000_000e18);
        _assertMorphoCap(Ethereum.MORPHO_VAULT_DAI_1, ptsusdemay, 200_000_000e18);

        // --- Test the new May PT market is seeded ---
        assertGe(IMorpho(MORPHO).market(MarketParamsLib.id(ptsusdemay)).totalSupplyAssets, 1e18);

        // --- Test the May PT Oracle in more detail ---

        uint256 ptSUSDE29MAY2025Price = IMorphoChainlinkOracle(PT_SUSDE_29MAY2025_PRICE_FEED).price();

        assertEq(ptSUSDE29MAY2025Price, 0.903243903792491122e36);

        uint256 timeSkip = 60 days;
        skip(timeSkip);

        uint256 newPTSUSDE29MAY2025Price = IMorphoChainlinkOracle(PT_SUSDE_29MAY2025_PRICE_FEED).price();

        // Price for both feeds increases over time
        assertGt(newPTSUSDE29MAY2025Price, ptSUSDE29MAY2025Price);

        uint256 ptSUSDE29MAY2025YearlyPriceIncrease = (newPTSUSDE29MAY2025Price - ptSUSDE29MAY2025Price) * 365 days / (timeSkip);

        // Calculated yield should equal the expected one
        assertApproxEqAbs(ptSUSDE29MAY2025YearlyPriceIncrease / 1e18, PT_SUSDE_29MAY2025_YIELD, 4);

        assertLt(IMorphoChainlinkOracle(PT_SUSDE_29MAY2025_PRICE_FEED).price(), 1e36);

        // Prices on maturity should be 1e36
        vm.warp(IPendlePT(PT_SUSDE_29MAY2025).expiry());
        assertEq(IMorphoChainlinkOracle(PT_SUSDE_29MAY2025_PRICE_FEED).price(), 1e36);

        skip(365 days);

        // Prices should remain to be 1e36
        assertEq(IMorphoChainlinkOracle(PT_SUSDE_29MAY2025_PRICE_FEED).price(), 1e36);
    }

    function test_ETHEREUM_StablecoinUpdates() public onChain(ChainIdUtils.Ethereum()) {
        loadPoolContext(_getPoolAddressesProviderRegistry().getAddressesProvidersList()[0]);
        
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore  = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        ReserveConfig memory usdcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDC');
        ReserveConfig memory usdtConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDT');

        assertEq(daiConfigBefore.interestRateStrategy,  OLD_DAI_INTEREST_RATE_STRATEGY);
        assertEq(usdcConfigBefore.interestRateStrategy, OLD_STABLECOINS_INTEREST_RATE_STRATEGY);
        assertEq(usdtConfigBefore.interestRateStrategy, OLD_STABLECOINS_INTEREST_RATE_STRATEGY);

        // DSR + 1% APR
        uint256 expectedPrevDaiBaseVariableBorrowRate = 0.118244145468537494478864e27;

        // Approx 12.5% APY (deviation due to addition of APR)
        assertEq(_getAPY(expectedPrevDaiBaseVariableBorrowRate), 0.125518867907576113321554893e27);

        _validateInterestRateStrategy(
            daiConfigBefore.interestRateStrategy,
            OLD_DAI_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(IDefaultInterestRateStrategy(daiConfigBefore.interestRateStrategy).ADDRESSES_PROVIDER()),
                optimalUsageRatio:             1e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        expectedPrevDaiBaseVariableBorrowRate,
                variableRateSlope1:            0,
                variableRateSlope2:            0
            })
        );

        IDefaultInterestRateStrategy prevIRM = IDefaultInterestRateStrategy(usdcConfigBefore.interestRateStrategy);
        uint256 currVarSlope1 = 0.11885440509995120663752e27;

        // Approx 12.5% APY, but off by a bit because 11.5% DSR APY + 1% APR != 12.5% APY
        assertEq(_getAPY(currVarSlope1), 0.126205936258187976959810466e27);

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

        // Will be almost exactly 12.5% APY
        assertEq(_getAPY(newVarSlope1), 0.124999999999999999980492118e27);

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

    function test_ETHEREUM_ControllerUpgrade() public onChain(ChainIdUtils.Ethereum()) {
        // Deployment configuration is checked inside the spell

        MainnetController controller = MainnetController(NEW_ALM_CONTROLLER);
        IALMProxy proxy              = IALMProxy(Ethereum.ALM_PROXY);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);

        assertEq(proxy.hasRole(proxy.CONTROLLER(), Ethereum.ALM_CONTROLLER),           true);
        assertEq(proxy.hasRole(proxy.CONTROLLER(), NEW_ALM_CONTROLLER),                false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Ethereum.ALM_CONTROLLER), true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), NEW_ALM_CONTROLLER),      false);
        assertEq(controller.hasRole(controller.RELAYER(), Ethereum.ALM_RELAYER),       false);
        assertEq(controller.hasRole(controller.FREEZER(), Ethereum.ALM_FREEZER),       false);
        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),       bytes32(uint256(uint160(address(0)))));

        executeAllPayloadsAndBridges();

        assertEq(proxy.hasRole(proxy.CONTROLLER(), Ethereum.ALM_CONTROLLER),           false);
        assertEq(proxy.hasRole(proxy.CONTROLLER(), NEW_ALM_CONTROLLER),                true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Ethereum.ALM_CONTROLLER), false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), NEW_ALM_CONTROLLER),      true);
        assertEq(controller.hasRole(controller.RELAYER(), Ethereum.ALM_RELAYER),       true);
        assertEq(controller.hasRole(controller.FREEZER(), Ethereum.ALM_FREEZER),       true);
        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),       bytes32(uint256(uint160(address(Base.ALM_PROXY)))));
    }

    function test_ETHEREUM_EthenaOnboardingIntegration() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        MainnetController controller = MainnetController(NEW_ALM_CONTROLLER);
        
        IERC20 usdc    = IERC20(Ethereum.USDC);
        IERC20 usde    = IERC20(Ethereum.USDE);
        IERC4626 susde = IERC4626(Ethereum.SUSDE);

        // Use a realistic numbers to check the rate limits
        uint256 usdcAmount = 5_000_000e6;
        uint256 usdeAmount = usdcAmount * 1e12;

        // Use deal2 for USDC because storage is not set in a common way
        deal2(Ethereum.USDC, Ethereum.ALM_PROXY, usdcAmount);

        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 0);
        
        vm.startPrank(Ethereum.ALM_RELAYER);

        controller.prepareUSDeMint(usdcAmount);

        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), usdcAmount);

        // Fake the offchain swap
        // Need to also stop pranking because deal2 uses prank
        vm.stopPrank();
        deal2(Ethereum.USDC, Ethereum.ALM_PROXY, 0);
        vm.startPrank(Ethereum.ALM_RELAYER);
        deal(Ethereum.USDE, Ethereum.ALM_PROXY, usdeAmount);

        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  usdeAmount);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), 0);

        uint256 susdeAmount = susde.previewDeposit(usdeAmount);
        assertGt(susdeAmount, 0);

        controller.depositERC4626(Ethereum.SUSDE, usdeAmount);

        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  0);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), susdeAmount);

        controller.cooldownSharesSUSDe(susdeAmount);

        // Assets are locked in the silo
        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  0);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), 0);

        skip(7 days - 1);

        vm.expectRevert(abi.encodeWithSignature("InvalidCooldown()"));
        controller.unstakeSUSDe();

        skip(1);

        uint256 snapshot = vm.snapshot();

        controller.unstakeSUSDe();

        usdeAmount -= 1;  // Rounding

        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  usdeAmount);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), 0);

        assertEq(usde.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 0);

        vm.revertTo(snapshot);

        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  0);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), 0);

        // Test unstaking with cooldown set to zero
        vm.stopPrank();
        vm.prank(ETHENA_OWNER);
        IEthenaMinter(Ethereum.SUSDE).setCooldownDuration(0);
        vm.startPrank(Ethereum.ALM_RELAYER);
        controller.unstakeSUSDe();

        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  usdeAmount);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), 0);

        assertEq(usde.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 0);

        controller.prepareUSDeBurn(usdeAmount);

        assertEq(usde.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), usdeAmount);
    }


    function test_ETHEREUM_EthenaAfterCooldownIsDisabled() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        MainnetController controller = MainnetController(NEW_ALM_CONTROLLER);
        
        IERC20 usdc    = IERC20(Ethereum.USDC);
        IERC20 usde    = IERC20(Ethereum.USDE);
        IERC4626 susde = IERC4626(Ethereum.SUSDE);

        // Use a realistic numbers to check the rate limits
        uint256 usdcAmount = 5_000_000e6;
        uint256 usdeAmount = usdcAmount * 1e12;

        vm.prank(ETHENA_OWNER);
        IEthenaMinter(Ethereum.SUSDE).setCooldownDuration(0);

        // Use deal2 for USDC because storage is not set in a common way
        deal2(Ethereum.USDC, Ethereum.ALM_PROXY, usdcAmount);

        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), 0);
        
        vm.startPrank(Ethereum.ALM_RELAYER);

        controller.prepareUSDeMint(usdcAmount);

        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER), usdcAmount);

        // Fake the offchain swap
        // Need to also stop pranking because deal2 uses prank
        vm.stopPrank();
        deal2(Ethereum.USDC, Ethereum.ALM_PROXY, 0);
        vm.startPrank(Ethereum.ALM_RELAYER);
        deal(Ethereum.USDE, Ethereum.ALM_PROXY, usdeAmount);

        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  usdeAmount);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), 0);

        uint256 susdeAmount = susde.previewDeposit(usdeAmount);
        assertGt(susdeAmount, 0);

        controller.depositERC4626(Ethereum.SUSDE, usdeAmount);

        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  0);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), susdeAmount);
        vm.stopPrank();

        // Test unstaking with cooldown set to zero
        vm.startPrank(Ethereum.ALM_RELAYER);

        // unstaking without cooling down shares first is a no-op
        address usdeSilo = 0x7FC7c91D556B400AFa565013E3F32055a0713425;
        vm.expectEmit();
        emit IERC20.Transfer(usdeSilo, Ethereum.ALM_PROXY, 0);
        controller.unstakeSUSDe();
        // assets not yet locked in silo
        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),  0);
        assertEq(susde.balanceOf(Ethereum.ALM_PROXY), susdeAmount);

        // withdrawing via the ERC4626 (as suggested in cantina report 3.2.4) is 
        // not possible since rate limit was not set
        vm.expectRevert("RateLimits/zero-maxAmount");
        controller.withdrawERC4626(
            Ethereum.SUSDE,
            usdeAmount / 2 // don't care about exact amount, only if *some* withdraw is possible
        );

        // `cooldownSharesSUSDe` reverts when the cooldown is disabled, and
        // sUSDe cant be unstaked until next spell
        vm.expectRevert(IEthenaMinter.OperationNotAllowed.selector);
        controller.cooldownSharesSUSDe(susdeAmount);
    }

    function test_ETHEREUM_EthenaRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(NEW_ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);

        bytes32 depositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_DEPOSIT(),
            Ethereum.SUSDE
        );

        bytes32 withdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_WITHDRAW(),
            Ethereum.SUSDE
        );

        // All rates are zero initially
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_MINT()),      0);
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_BURN()),      0);
        assertEq(rateLimits.getCurrentRateLimit(depositKey),                        0);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey),                       0);
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_SUSDE_COOLDOWN()), 0);

        executeAllPayloadsAndBridges();
        
        IERC20 usdc    = IERC20(Ethereum.USDC);
        IERC20 usde    = IERC20(Ethereum.USDE);
        IERC4626 susde = IERC4626(Ethereum.SUSDE);
        
        vm.startPrank(Ethereum.ALM_RELAYER);

        // Mint

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_MINT()), 50_000_000e6);
        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER),   0);

        controller.prepareUSDeMint(50_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_MINT()), 0);
        assertEq(usdc.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER),   50_000_000e6);

        // Burn

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_BURN()), 100_000_000e18);
        assertEq(usde.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER),   0);

        controller.prepareUSDeBurn(100_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_BURN()), 0);
        assertEq(usde.allowance(Ethereum.ALM_PROXY, Ethereum.ETHENA_MINTER),   100_000_000e18);

        // sUSDe Deposit

        deal(Ethereum.USDE, Ethereum.ALM_PROXY, 100_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),                 100_000_000e18);
        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),                         100_000_000e18);
        assertEq(susde.convertToAssets(susde.balanceOf(Ethereum.ALM_PROXY)), 0);

        controller.depositERC4626(address(susde), 100_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),                 0);
        assertEq(usde.balanceOf(Ethereum.ALM_PROXY),                         0);
        assertEq(susde.convertToAssets(susde.balanceOf(Ethereum.ALM_PROXY)), 100_000_000e18 - 1);  // Rounding

        // sUSDe Cooldown

        deal(Ethereum.SUSDE, Ethereum.ALM_PROXY, susde.convertToShares(500_000_000e18) + 1);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_SUSDE_COOLDOWN()), 500_000_000e18);
        assertEq(susde.convertToAssets(susde.balanceOf(Ethereum.ALM_PROXY)),        500_000_000e18 + 1);  // Rounding
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey),                       0);

        controller.cooldownAssetsSUSDe(500_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_SUSDE_COOLDOWN()), 0);
        assertEq(susde.convertToAssets(susde.balanceOf(Ethereum.ALM_PROXY)),        0);

        // Confirm proper recharge rate
        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_MINT()),      50_000_000e6 / uint256(1 days) * 1 hours);
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_BURN()),      100_000_000e18 / uint256(1 days) * 1 hours);
        assertEq(rateLimits.getCurrentRateLimit(depositKey),                        100_000_000e18 / uint256(1 days) * 1 hours);
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_SUSDE_COOLDOWN()), 250_000_000e18 / uint256(1 days) * 1 hours);

        // All limits should be reset in 2 days + 1 (rounding)
        skip(47 hours + 1);

        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_MINT()),      50_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_USDE_BURN()),      100_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(depositKey),                        100_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(controller.LIMIT_SUSDE_COOLDOWN()), 500_000_000e18);
    }

    function test_ETHEREUM_AaveOnboardingIntegration() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        MainnetController controller = MainnetController(NEW_ALM_CONTROLLER);
        
        IERC20 usds  = IERC20(Ethereum.USDS);
        IERC20 usdc  = IERC20(Ethereum.USDC);
        IERC20 ausds = IERC20(ATOKEN_USDS);
        IERC20 ausdc = IERC20(ATOKEN_USDC);

        // Use a realistic numbers to check the rate limits
        uint256 usdsAmount = 5_000_000e18;
        uint256 usdcAmount = 5_000_000e6;

        deal(Ethereum.USDS, Ethereum.ALM_PROXY, usdsAmount);
        // Use deal2 for USDC because storage is not set in a common way
        deal2(Ethereum.USDC, Ethereum.ALM_PROXY, usdcAmount);

        // USDS

        assertEq(usds.balanceOf(Ethereum.ALM_PROXY),  usdsAmount);
        assertEq(ausds.balanceOf(Ethereum.ALM_PROXY), 0);

        vm.startPrank(Ethereum.ALM_RELAYER);

        controller.depositAave(ATOKEN_USDS, usdsAmount);

        assertEq(usds.balanceOf(Ethereum.ALM_PROXY),  0);
        assertEq(ausds.balanceOf(Ethereum.ALM_PROXY), usdsAmount);

        controller.withdrawAave(ATOKEN_USDS, usdsAmount);

        assertEq(usds.balanceOf(Ethereum.ALM_PROXY),  usdsAmount);
        assertEq(ausds.balanceOf(Ethereum.ALM_PROXY), 0);

        // USDC

        assertEq(usdc.balanceOf(Ethereum.ALM_PROXY),  usdcAmount);
        assertEq(ausdc.balanceOf(Ethereum.ALM_PROXY), 0);

        controller.depositAave(ATOKEN_USDC, usdcAmount);

        assertEq(usdc.balanceOf(Ethereum.ALM_PROXY),  0);
        assertEq(ausdc.balanceOf(Ethereum.ALM_PROXY), usdcAmount);

        controller.withdrawAave(ATOKEN_USDC, usdcAmount);

        assertEq(usdc.balanceOf(Ethereum.ALM_PROXY),  usdcAmount);
        assertEq(ausdc.balanceOf(Ethereum.ALM_PROXY), 0);
    }

    function test_ETHEREUM_AaveRateLimits() public onChain(ChainIdUtils.Ethereum()) {
        MainnetController controller = MainnetController(NEW_ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Ethereum.ALM_RATE_LIMITS);
        
        IERC20 usds  = IERC20(Ethereum.USDS);
        IERC20 usdc  = IERC20(Ethereum.USDC);
        IERC20 ausds = IERC20(ATOKEN_USDS);
        IERC20 ausdc = IERC20(ATOKEN_USDC);

        bytes32 usdsDepositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_DEPOSIT(),
            address(ausds)
        );
        bytes32 usdsWithdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_WITHDRAW(),
            address(ausds)
        );

        bytes32 usdcDepositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_DEPOSIT(),
            address(ausdc)
        );
        bytes32 usdcWithdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_WITHDRAW(),
            address(ausdc)
        );

        assertEq(rateLimits.getCurrentRateLimit(usdsDepositKey),  0);
        assertEq(rateLimits.getCurrentRateLimit(usdsWithdrawKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey),  0);
        assertEq(rateLimits.getCurrentRateLimit(usdcWithdrawKey), 0);

        executeAllPayloadsAndBridges();

        deal(Ethereum.USDS, Ethereum.ALM_PROXY, 50_000_000e18);
        // Use deal2 for USDC because storage is not set in a common way
        deal2(Ethereum.USDC, Ethereum.ALM_PROXY, 50_000_000e6);

        // USDS

        vm.startPrank(Ethereum.ALM_RELAYER);

        assertEq(rateLimits.getCurrentRateLimit(usdsDepositKey), 50_000_000e18);
        assertEq(usds.balanceOf(Ethereum.ALM_PROXY),             50_000_000e18);
        assertEq(ausds.balanceOf(Ethereum.ALM_PROXY),            0);

        controller.depositAave(address(ausds), 50_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(usdsDepositKey), 0);
        assertEq(usds.balanceOf(Ethereum.ALM_PROXY),             0);
        assertEq(ausds.balanceOf(Ethereum.ALM_PROXY),            50_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(usdsWithdrawKey), type(uint256).max);

        // USDC

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 50_000_000e6);
        assertEq(usdc.balanceOf(Ethereum.ALM_PROXY),             50_000_000e6);
        assertEq(ausdc.balanceOf(Ethereum.ALM_PROXY),            0);

        controller.depositAave(address(ausdc), 50_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 0);
        assertEq(usdc.balanceOf(Ethereum.ALM_PROXY),             0);
        assertEq(ausdc.balanceOf(Ethereum.ALM_PROXY),            50_000_000e6 - 1);  // Rounding

        assertEq(rateLimits.getCurrentRateLimit(usdcWithdrawKey), type(uint256).max);

        // Confirm proper recharge rate
        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(usdsDepositKey), 25_000_000e18 / uint256(1 days) * 1 hours);
        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 25_000_000e6 / uint256(1 days) * 1 hours);

        // All limits should be reset in 2 days + 1 (rounding)
        skip(47 hours + 1);

        assertEq(rateLimits.getCurrentRateLimit(usdsDepositKey), 50_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 50_000_000e6);
    }

    function test_BASE_ControllerUpgrade() public onChain(ChainIdUtils.Base()) {
        // Deployment configuration is checked inside the spell

        ForeignController controller = ForeignController(BASE_NEW_ALM_CONTROLLER);
        IALMProxy proxy              = IALMProxy(Base.ALM_PROXY);
        IRateLimits rateLimits       = IRateLimits(Base.ALM_RATE_LIMITS);

        assertEq(proxy.hasRole(proxy.CONTROLLER(), Base.ALM_CONTROLLER),               true);
        assertEq(proxy.hasRole(proxy.CONTROLLER(), BASE_NEW_ALM_CONTROLLER),           false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Base.ALM_CONTROLLER),     true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), BASE_NEW_ALM_CONTROLLER), false);
        assertEq(controller.hasRole(controller.RELAYER(), Base.ALM_RELAYER),           false);
        assertEq(controller.hasRole(controller.FREEZER(), Base.ALM_FREEZER),           false);
        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),   bytes32(uint256(uint160(address(0)))));

        executeAllPayloadsAndBridges();

        assertEq(proxy.hasRole(proxy.CONTROLLER(), Base.ALM_CONTROLLER),               false);
        assertEq(proxy.hasRole(proxy.CONTROLLER(), BASE_NEW_ALM_CONTROLLER),           true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), Base.ALM_CONTROLLER),     false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), BASE_NEW_ALM_CONTROLLER), true);
        assertEq(controller.hasRole(controller.RELAYER(), Base.ALM_RELAYER),           true);
        assertEq(controller.hasRole(controller.FREEZER(), Base.ALM_FREEZER),           true);
        assertEq(controller.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),   bytes32(uint256(uint160(address(Ethereum.ALM_PROXY)))));
    }

    function test_BASE_AaveOnboardingIntegration() public onChain(ChainIdUtils.Base()) {
        executeAllPayloadsAndBridges();

        ForeignController controller = ForeignController(BASE_NEW_ALM_CONTROLLER);
        
        IERC20 usdc  = IERC20(Base.USDC);
        IERC20 ausdc = IERC20(BASE_ATOKEN_USDC);

        // Use a realistic numbers to check the rate limits
        uint256 usdcAmount = 5_000_000e6;

        // Use deal2 for USDC because storage is not set in a common way
        deal2(Base.USDC, Base.ALM_PROXY, usdcAmount);

        assertEq(usdc.balanceOf(Base.ALM_PROXY),  usdcAmount);
        assertEq(ausdc.balanceOf(Base.ALM_PROXY), 0);

        vm.startPrank(Base.ALM_RELAYER);

        controller.depositAave(BASE_ATOKEN_USDC, usdcAmount);

        assertEq(usdc.balanceOf(Base.ALM_PROXY),  0);
        assertEq(ausdc.balanceOf(Base.ALM_PROXY), usdcAmount);

        controller.withdrawAave(BASE_ATOKEN_USDC, usdcAmount);

        assertEq(usdc.balanceOf(Base.ALM_PROXY),  usdcAmount);
        assertEq(ausdc.balanceOf(Base.ALM_PROXY), 0);
    }

    function test_BASE_AaveRateLimits() public onChain(ChainIdUtils.Base()) {
        MainnetController controller = MainnetController(BASE_NEW_ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Base.ALM_RATE_LIMITS);
        
        IERC20 usdc  = IERC20(Base.USDC);
        IERC20 ausdc = IERC20(BASE_ATOKEN_USDC);

        bytes32 usdcDepositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_DEPOSIT(),
            address(ausdc)
        );
        bytes32 usdcWithdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_AAVE_WITHDRAW(),
            address(ausdc)
        );

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 0);

        executeAllPayloadsAndBridges();

        // Use deal2 for USDC because storage is not set in a common way
        deal2(Base.USDC, Base.ALM_PROXY, 50_000_000e6);

        vm.startPrank(Base.ALM_RELAYER);

        // USDC

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 50_000_000e6);
        assertEq(usdc.balanceOf(Base.ALM_PROXY),                 50_000_000e6);
        assertEq(ausdc.balanceOf(Base.ALM_PROXY),                0);

        controller.depositAave(address(ausdc), 50_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 0);
        assertEq(usdc.balanceOf(Base.ALM_PROXY),                 0);
        assertEq(ausdc.balanceOf(Base.ALM_PROXY),                50_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdcWithdrawKey), type(uint256).max);

        // Confirm proper recharge rate
        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 25_000_000e6 / uint256(1 days) * 1 hours);

        // All limits should be reset in 2 days + 1 (rounding)
        skip(47 hours + 1);

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 50_000_000e6);
    }

    function test_BASE_MorphoVaultDeploy() public onChain(ChainIdUtils.Base()) {
        IMetaMorpho susdc = IMetaMorpho(BASE_MORPHO_SPARK_USDC);

        assertEq(susdc.name(),     "Spark USDC Vault");
        assertEq(susdc.symbol(),   "sparkUSDC");

        // The vault should be such that the Spark admin is the owner with nothing else configured
        assertEq(susdc.owner(),               Base.SPARK_EXECUTOR);
        assertEq(susdc.curator(),             address(0));
        assertEq(susdc.guardian(),            address(0));
        assertEq(susdc.fee(),                 0);
        assertEq(susdc.feeRecipient(),        address(0));
        assertEq(susdc.skimRecipient(),       address(0));
        assertEq(susdc.timelock(),            0);
        assertEq(susdc.supplyQueueLength(),   0);
        assertEq(susdc.withdrawQueueLength(), 0);
    }

    function test_BASE_MorphoConfiguration() public onChain(ChainIdUtils.Base()) {
        IMetaMorpho susdc = IMetaMorpho(BASE_MORPHO_SPARK_USDC);

        MarketParams memory usdcIdle = MarketParams({
            loanToken:       Base.USDC,
            collateralToken: address(0),
            oracle:          address(0),
            irm:             address(0),
            lltv:            0
        });
        MarketParams memory usdcCBBTC =  MarketParams({
            loanToken:       Base.USDC,
            collateralToken: BASE_CBBTC,
            oracle:          BASE_CBBTC_USDC_ORACLE,
            irm:             BASE_MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        });

        _assertMorphoCap(address(susdc), usdcIdle,  0);
        _assertMorphoCap(address(susdc), usdcCBBTC, 0);
        
        assertEq(susdc.isAllocator(Base.ALM_RELAYER), false);

        executeAllPayloadsAndBridges();
        
        _assertMorphoCap(address(susdc), usdcIdle,  type(uint184).max);
        _assertMorphoCap(address(susdc), usdcCBBTC, 100_000_000e6);
        
        assertEq(susdc.isAllocator(Base.ALM_RELAYER), true);

        // --- Test the markets are seeded ---
        assertGe(IMorpho(MORPHO).market(MarketParamsLib.id(usdcIdle)).totalSupplyAssets,  1e6);
        assertGe(IMorpho(MORPHO).market(MarketParamsLib.id(usdcCBBTC)).totalSupplyAssets, 1e8);
    }

    function test_BASE_MorphoVaultIntegration() public onChain(ChainIdUtils.Base()) {
        executeAllPayloadsAndBridges();

        ForeignController controller = ForeignController(BASE_NEW_ALM_CONTROLLER);
        IMorpho morpho               = IMorpho(MORPHO);

        IERC20 usdc       = IERC20(Base.USDC);
        IMetaMorpho susdc = IMetaMorpho(BASE_MORPHO_SPARK_USDC);

        // Use a realistic numbers to check the rate limits
        uint256 usdcAmount = 5_000_000e6;

        // Use deal2 for USDC because storage is not set in a common way
        deal2(Base.USDC, Base.ALM_PROXY, usdcAmount);

        vm.startPrank(Base.ALM_RELAYER);

        MarketParams memory usdcIdle = MarketParams({
            loanToken:       Base.USDC,
            collateralToken: address(0),
            oracle:          address(0),
            irm:             address(0),
            lltv:            0
        });
        MarketParams memory usdcCBBTC =  MarketParams({
            loanToken:       Base.USDC,
            collateralToken: BASE_CBBTC,
            oracle:          BASE_CBBTC_USDC_ORACLE,
            irm:             BASE_MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        });
        uint256 susdcAmount = susdc.previewDeposit(usdcAmount);

        assertEq(usdc.balanceOf(Base.ALM_PROXY),  usdcAmount);
        assertEq(susdc.balanceOf(Base.ALM_PROXY), 0);

        controller.depositERC4626(BASE_MORPHO_SPARK_USDC, usdcAmount);

        assertEq(usdc.balanceOf(Base.ALM_PROXY),  0);
        assertEq(susdc.balanceOf(Base.ALM_PROXY), susdcAmount);

        // Note: Greater than
        assertGt(morpho.position(MarketParamsLib.id(usdcIdle), BASE_MORPHO_SPARK_USDC).supplyShares,  0);
        assertEq(morpho.position(MarketParamsLib.id(usdcCBBTC), BASE_MORPHO_SPARK_USDC).supplyShares, 0);

        // The relayer can reallocate the funds into the cbBTC market
        MarketAllocation[] memory reallocation = new MarketAllocation[](2);
        reallocation[0] = MarketAllocation({
            marketParams: usdcIdle,
            assets:       0
        });
        reallocation[1] = MarketAllocation({
            marketParams: usdcCBBTC,
            assets:       usdcAmount 
        });
        susdc.reallocate(reallocation);

        assertEq(morpho.position(MarketParamsLib.id(usdcIdle), BASE_MORPHO_SPARK_USDC).supplyShares,  0);
        // Note: Greater than
        assertGt(morpho.position(MarketParamsLib.id(usdcCBBTC), BASE_MORPHO_SPARK_USDC).supplyShares, 0);

        usdcAmount -= 1;  // Rounding

        controller.withdrawERC4626(BASE_MORPHO_SPARK_USDC, usdcAmount);

        assertEq(usdc.balanceOf(Base.ALM_PROXY),  usdcAmount);
        assertEq(susdc.balanceOf(Base.ALM_PROXY), 1e12);  // Some dust left

        // Third party can deposit in vault
        vm.stopPrank();
        deal2(Base.USDC, address(this), 100e6);
        usdc.approve(address(susdc), 100e6);

        assertEq(susdc.balanceOf(address(this)), 0);

        susdc.deposit(100e6, address(this));

        assertEq(susdc.balanceOf(address(this)), 100e18);
    }

    function test_BASE_MorphoRateLimits() public onChain(ChainIdUtils.Base()) {
        MainnetController controller = MainnetController(BASE_NEW_ALM_CONTROLLER);
        IRateLimits rateLimits       = IRateLimits(Base.ALM_RATE_LIMITS);
        
        IERC20 usdc    = IERC20(Base.USDC);
        IERC4626 susdc = IERC4626(BASE_MORPHO_SPARK_USDC);

        bytes32 usdcDepositKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_DEPOSIT(),
            address(susdc)
        );
        bytes32 usdcWithdrawKey = RateLimitHelpers.makeAssetKey(
            controller.LIMIT_4626_WITHDRAW(),
            address(susdc)
        );

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey),  0);
        assertEq(rateLimits.getCurrentRateLimit(usdcWithdrawKey), 0);

        executeAllPayloadsAndBridges();

        // Use deal2 for USDC because storage is not set in a common way
        deal2(Base.USDC, Base.ALM_PROXY, 50_000_000e6);

        vm.startPrank(Base.ALM_RELAYER);

        // USDC

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey),         50_000_000e6);
        assertEq(usdc.balanceOf(Base.ALM_PROXY),                         50_000_000e6);
        assertEq(susdc.convertToAssets(susdc.balanceOf(Base.ALM_PROXY)), 0);

        controller.depositERC4626(address(susdc), 50_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey),         0);
        assertEq(usdc.balanceOf(Base.ALM_PROXY),                         0);
        assertEq(susdc.convertToAssets(susdc.balanceOf(Base.ALM_PROXY)), 50_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdcWithdrawKey), type(uint256).max);

        // Confirm proper recharge rate
        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 25_000_000e6 / uint256(1 days) * 1 hours);

        // All limits should be reset in 2 days + 1 (rounding)
        skip(47 hours + 1);

        assertEq(rateLimits.getCurrentRateLimit(usdcDepositKey), 50_000_000e6);
    }

    function test_ETHEREUM_BASE_USDSBridging() public onChain(ChainIdUtils.Base()) {
        uint256 baseBalanceBefore = IERC20(Base.USDS).balanceOf(Base.ALM_PROXY);

        executeAllPayloadsAndBridges();

        assertEq(IERC20(Base.USDS).balanceOf(Base.ALM_PROXY), baseBalanceBefore + USDS_MINT_AMOUNT);
    }

    function test_ETHEREUM_BASE_SparkLiquidityLayerE2E() public onChain(ChainIdUtils.Ethereum()) {
        executeAllPayloadsAndBridges();

        uint256 usdcAmount = 100_000e6;

        vm.startPrank(Ethereum.ALM_RELAYER);
        MainnetController(NEW_ALM_CONTROLLER).mintUSDS(usdcAmount * 1e12);
        MainnetController(NEW_ALM_CONTROLLER).swapUSDSToUSDC(usdcAmount);
        MainnetController(NEW_ALM_CONTROLLER).transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();

        uint256 initialUsdc = IERC20(Base.USDC).balanceOf(Base.ALM_PROXY);

        _relayMessageOverBridges();

        assertEq(IERC20(Base.USDC).balanceOf(Base.ALM_PROXY), initialUsdc + usdcAmount);

        vm.startPrank(Base.ALM_RELAYER);
        MainnetController(BASE_NEW_ALM_CONTROLLER).transferUSDCToCCTP(usdcAmount, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
        vm.stopPrank();

        chainSpellMetadata[ChainIdUtils.Ethereum()].domain.selectFork();

        initialUsdc = IERC20(Ethereum.USDC).balanceOf(Ethereum.ALM_PROXY);

        _relayMessageOverBridges();

        assertEq(IERC20(Ethereum.USDC).balanceOf(Ethereum.ALM_PROXY), initialUsdc + usdcAmount);
    }

}
