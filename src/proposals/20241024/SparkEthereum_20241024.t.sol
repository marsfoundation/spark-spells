// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20241024 } from './SparkEthereum_20241024.sol';

contract SparkEthereum_20241024Test is SparkEthereumTestBase {

    address public constant USDC                            = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT                            = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public constant OLD_USDC_ORACLE                 = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant OLD_USDT_ORACLE                 = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address public constant FIXED_PRICE_ORACLE              = 0x42a03F81dd8A1cEcD746dc262e4d1CD9fD39F777;

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY  = 0x7d8f2210FAD012E7d260C3ddBeCaCfd48277455F;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY  = 0x7d8f2210FAD012E7d260C3ddBeCaCfd48277455F; // TBA (this is a placeholders)
    address public constant OLD_USDC_INTEREST_RATE_STRATEGY = 0xbc8A68B0ab0617D7c90d15bb1601B25d795Dc4c8;
    address public constant NEW_USDC_INTEREST_RATE_STRATEGY = 0x0F1a9a787b4103eF5929121CD9399224c6455dD6;
    address public constant OLD_USDT_INTEREST_RATE_STRATEGY = 0xbc8A68B0ab0617D7c90d15bb1601B25d795Dc4c8;
    address public constant NEW_USDT_INTEREST_RATE_STRATEGY = 0x0F1a9a787b4103eF5929121CD9399224c6455dD6;

    uint256 public constant OLD_WBTC_SUPPLY_CAP = 3_000;
    uint256 public constant NEW_WBTC_SUPPLY_CAP = 5_000;

    constructor() {
        id = '20241024';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
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

        /*************************************************/
        /*** DAI, USDC & USDT Oracle Before Assertions ***/
        /*************************************************/

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        ReserveConfig memory usdcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDC');
        assertEq(usdcConfigBefore.interestRateStrategy, OLD_USDC_INTEREST_RATE_STRATEGY);

        ReserveConfig memory usdtConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDT');
        assertEq(usdtConfigBefore.interestRateStrategy, OLD_USDT_INTEREST_RATE_STRATEGY);

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

        /************************************************/
        /*** DAI, USDC & USDT Oracle After Assertions ***/
        /************************************************/

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');
        assertEq(daiConfigAfter.interestRateStrategy, NEW_DAI_INTEREST_RATE_STRATEGY);

        ReserveConfig memory usdcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDC');
        assertEq(usdcConfigAfter.interestRateStrategy, NEW_USDC_INTEREST_RATE_STRATEGY);

        ReserveConfig memory usdtConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDT');
        assertEq(usdtConfigAfter.interestRateStrategy, NEW_USDT_INTEREST_RATE_STRATEGY);
    }

}
