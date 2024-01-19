// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

interface IIRM {
    function RATE_SOURCE() external view returns (address);
}

interface IRateSource {
    function getAPR() external view returns (int256);
}

contract SparkEthereum_20240124Test is SparkEthereumTestBase {

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public constant OLD_USDC_ORACLE    = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant OLD_USDT_ORACLE    = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address public constant FIXED_PRICE_ORACLE = 0x42a03F81dd8A1cEcD746dc262e4d1CD9fD39F777;

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY  = 0x7d8f2210FAD012E7d260C3ddBeCaCfd48277455F;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY  = 0x512AFEDCF6696d9707dCFECD4bdc73e9902e3c6A;
    address public constant OLD_USDC_INTEREST_RATE_STRATEGY = 0xbc8A68B0ab0617D7c90d15bb1601B25d795Dc4c8;
    address public constant NEW_USDC_INTEREST_RATE_STRATEGY = 0x0F1a9a787b4103eF5929121CD9399224c6455dD6;
    address public constant OLD_USDT_INTEREST_RATE_STRATEGY = 0xbc8A68B0ab0617D7c90d15bb1601B25d795Dc4c8;
    address public constant NEW_USDT_INTEREST_RATE_STRATEGY = 0x0F1a9a787b4103eF5929121CD9399224c6455dD6;

    uint256 public constant OLD_WBTC_SUPPLY_CAP   = 3_000;
    uint256 public constant NEW_WBTC_SUPPLY_CAP   = 5_000;
    uint256 public constant OLD_USDC_USDT_SLOPE_1 = 0.044790164207174267760128000e27;

    int256 public constant USDC_USDT_IRM_SPREAD = -0.004e27;
    int256 public constant DAI_IRM_SPREAD       =  0.013808977611475523600880000e27;

    constructor() {
        id = '20240124';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl,  19040494);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /********************************************/
        /*** USDC & USDT Oracle Before Assertions ***/
        /********************************************/

        _validateAssetSourceOnOracle(poolAddressesProvider, USDC, OLD_USDC_ORACLE);
        _validateAssetSourceOnOracle(poolAddressesProvider, USDT, OLD_USDT_ORACLE);

        /*****************************************/
        /*** WBTC Supply Cap Before Assertions ***/
        /*****************************************/

        ReserveConfig memory wbtcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');
        assertEq(wbtcConfigBefore.supplyCap, OLD_WBTC_SUPPLY_CAP);

        /**********************************************/
        /*** DAI, USDC & USDT IRM Before Assertions ***/
        /**********************************************/

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        ReserveConfig memory usdcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDC');
        ReserveConfig memory usdtConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDT');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        assertEq(OLD_USDC_INTEREST_RATE_STRATEGY, OLD_USDT_INTEREST_RATE_STRATEGY);

        _validateInterestRateStrategy(
            usdcConfigBefore.interestRateStrategy,
            OLD_USDC_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          OLD_USDC_USDT_SLOPE_1,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            OLD_USDC_USDT_SLOPE_1,
                variableRateSlope2:            0.2e27
            })
        );

        _validateInterestRateStrategy(
            usdtConfigBefore.interestRateStrategy,
            OLD_USDT_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          OLD_USDC_USDT_SLOPE_1,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            OLD_USDC_USDT_SLOPE_1,
                variableRateSlope2:            0.2e27
            })
        );

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /*******************************************/
        /*** USDC & USDT Oracle After Assertions ***/
        /*******************************************/

        _validateAssetSourceOnOracle(poolAddressesProvider, USDC, FIXED_PRICE_ORACLE);
        _validateAssetSourceOnOracle(poolAddressesProvider, USDT, FIXED_PRICE_ORACLE);

        /****************************************/
        /*** WBTC Supply Cap After Assertions ***/
        /****************************************/

        wbtcConfigBefore.supplyCap = NEW_WBTC_SUPPLY_CAP;
        _validateReserveConfig(wbtcConfigBefore, allConfigsAfter);

        /*********************************************/
        /*** DAI, USDC & USDT IRM After Assertions ***/
        /*********************************************/

        ReserveConfig memory daiConfigAfter  = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');
        ReserveConfig memory usdcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDC');
        ReserveConfig memory usdtConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDT');

        assertEq(IIRM(usdcConfigAfter.interestRateStrategy).RATE_SOURCE(), IIRM(usdtConfigAfter.interestRateStrategy).RATE_SOURCE());
        assertEq(IIRM(usdcConfigAfter.interestRateStrategy).RATE_SOURCE(), IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE());
        int256 potDsrApr = IRateSource(IIRM(usdcConfigAfter.interestRateStrategy).RATE_SOURCE()).getAPR();

        uint256 expectedDaiBaseVariableBorrowRate = uint256(potDsrApr + DAI_IRM_SPREAD);
        assertEq(expectedDaiBaseVariableBorrowRate, 0.062599141818649791361008000e27);

        _validateInterestRateStrategy(
            daiConfigAfter.interestRateStrategy,
            NEW_DAI_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
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

        assertEq(NEW_USDC_INTEREST_RATE_STRATEGY, NEW_USDT_INTEREST_RATE_STRATEGY);

        assertEq(OLD_USDC_USDT_SLOPE_1, uint256(potDsrApr + USDC_USDT_IRM_SPREAD));

        _validateInterestRateStrategy(
            usdcConfigAfter.interestRateStrategy,
            NEW_USDC_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          OLD_USDC_USDT_SLOPE_1,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            OLD_USDC_USDT_SLOPE_1,
                variableRateSlope2:            0.2e27
            })
        );

        _validateInterestRateStrategy(
            usdtConfigAfter.interestRateStrategy,
            NEW_USDT_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.95e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          OLD_USDC_USDT_SLOPE_1,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            OLD_USDC_USDT_SLOPE_1,
                variableRateSlope2:            0.2e27
            })
        );
    }

}
