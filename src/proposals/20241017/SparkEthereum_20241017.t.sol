// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}

interface IMorphoChainlinkOracle {
    function price() external view returns (uint256);
}

contract SparkEthereum_20241017Test is SparkEthereumTestBase {
    address internal constant SUSDS            = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant SUSDS_PRICE_FEED = 0x27f3A665c75aFdf43CfbF6B3A859B698f46ef656;

    address internal constant SDAI_OLD_PRICE_FEED = 0xb9E6DBFa4De19CCed908BcbFe1d015190678AB5f;
    address internal constant SDAI_PRICE_FEED     = 0x0c0864837C7e65458aCD3C665222203217019436;

    address internal constant PT_SUSDE_26DEC2024      = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;
    address internal constant PT_26DEC2024_PRICE_FEED = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address internal constant PT_SUSDE_27MAR2025      = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;
    address internal constant PT_27MAR2025_PRICE_FEED = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;

    constructor() {
        id = '20241017';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20926079);  // Oct 09, 2024
        payload = deployPayload();
        
        // TODO: Remove when the spark proxy has enough susds
        // Transfer SUSDS to spark proxy 
        vm.prank(0xf568680e62Adc0b05c90aAF89866dBa6F25aBBe2);
        IERC20(SUSDS).transfer(Ethereum.SPARK_PROXY, 1e6);

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testPriceFeeds() public {
        vm.startPrank(Ethereum.AAVE_ORACLE);
        assertEq(IPriceFeed(SUSDS_PRICE_FEED).latestAnswer(), 1.00362036e8);
        assertEq(IPriceFeed(SDAI_PRICE_FEED).latestAnswer(),  1.11239740e8);
    }

    function testValidatePriceFeedChange() public {
        IAaveOracle oracle = IAaveOracle(Ethereum.AAVE_ORACLE);

        assertEq(oracle.getSourceOfAsset(Ethereum.SDAI), SDAI_OLD_PRICE_FEED);
        assertEq(oracle.getAssetPrice(Ethereum.SDAI),    1.11215106e8);

        executePayload(payload);

        assertEq(oracle.getSourceOfAsset(Ethereum.SDAI), SDAI_PRICE_FEED);
        assertEq(oracle.getAssetPrice(Ethereum.SDAI),    1.11239740e8);
    }

    function testCollateralOnboarding() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        assertEq(allConfigsBefore.length, 11);

        _assertSupplyCapConfig({
            asset:            SUSDS,
            max:              0,
            gap:              0,
            increaseCooldown: 0
        });

        _assertBorrowCapConfig({
            asset:            SUSDS,
            max:              0,
            gap:              0,
            increaseCooldown: 0
        });

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        assertEq(allConfigsAfter.length, 12);

        ReserveConfig memory susds = ReserveConfig({
            symbol:                  'sUSDS',
            underlying:               SUSDS,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      79_00,
            liquidationThreshold:     80_00,
            liquidationBonus:         105_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            10_00,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         false,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'sUSDS').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          false,
            supplyCap:                50_000_000,
            borrowCap:                0,
            debtCeiling:              0,
            eModeCategory:            0
        });

        _validateReserveConfig(susds, allConfigsAfter);

        _validateInterestRateStrategy(
            susds.interestRateStrategy,
            susds.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.8e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.02e27,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.02e27,
                variableRateSlope2:            3e27
            })
        );
        
        _assertSupplyCapConfig({
            asset:            SUSDS,
            max:              500_000_000,
            gap:              50_000_000,
            increaseCooldown: 12 hours
        });

        _assertBorrowCapConfig({
            asset:            SUSDS,
            max:              0,
            gap:              0,
            increaseCooldown: 0
        });

        // The sUSDS price feed does not have a decimals() function so we validate manually
        IAaveOracle oracle = IAaveOracle(poolAddressesProvider.getPriceOracle());

        require(
            oracle.getSourceOfAsset(SUSDS) == SUSDS_PRICE_FEED,
            '_validateAssetSourceOnOracle() : INVALID_PRICE_SOURCE'
        );

        // require(
        //     IOracleLike(oracle.getSourceOfAsset(SUSDS)).decimals() == 8,
        //     '_validateAssetSourceOnOracle() : INVALID_PRICE_SOURCE_DECIMALS'
        // );
    }

    function testMorphoVaults() public {
        MarketParams memory ptUsde26Dec =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_26DEC2024,
            oracle:          PT_26DEC2024_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        MarketParams memory ptUsde27Mar =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_27MAR2025,
            oracle:          PT_27MAR2025_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        _assertMorphoCap(ptUsde26Dec, 0);
        _assertMorphoCap(ptUsde27Mar, 0);

        executePayload(payload);

        _assertMorphoCap(ptUsde26Dec, 0, 100_000_000e18);
        _assertMorphoCap(ptUsde27Mar, 0, 100_000_000e18);

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        skip(1 days);

        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptUsde26Dec);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptUsde27Mar);

        _assertMorphoCap(ptUsde26Dec, 100_000_000e18);
        _assertMorphoCap(ptUsde27Mar, 100_000_000e18);
        
        assertEq(IMorphoChainlinkOracle(PT_26DEC2024_PRICE_FEED).price(), 0.968457700722983258e36);
        assertEq(IMorphoChainlinkOracle(PT_27MAR2025_PRICE_FEED).price(), 0.908080587265347540e36);
    }

    function testWBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wbtcConfig = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold,   75_00);
        assertEq(wbtcConfig.liquidationProtocolFee, 10_00);

        _assertSupplyCapConfig({
            asset:            Ethereum.WBTC,
            max:              10_000,
            gap:              500,
            increaseCooldown: 12 hours
        });

        _assertBorrowCapConfig({
            asset:            Ethereum.WBTC,
            max:              2_000,
            gap:              100,
            increaseCooldown: 12 hours
        });

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        wbtcConfig.liquidationThreshold   = 70_00;
        wbtcConfig.liquidationProtocolFee = 0;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);

        _assertSupplyCapConfig({
            asset:            Ethereum.WBTC,
            max:              5_000,
            gap:              200,
            increaseCooldown: 12 hours
        });

        _assertBorrowCapConfig({
            asset:            Ethereum.WBTC,
            max:              1,
            gap:              1,
            increaseCooldown: 12 hours
        });
    }
}
