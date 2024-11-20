// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import {SparkEthereumTestBase, ReserveConfig, MarketParams, Ethereum, IMetaMorpho} from 'src/SparkTestBase.sol';

contract SparkEthereum_20241128Test is SparkEthereumTestBase {

    address internal constant PT_27MAR2025_PRICE_FEED = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address internal constant PT_SUSDE_27MAR2025      = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;

    constructor() {
        id = '20241128';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 21231255);  // Nov 20, 2024
        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
        payload = deployPayload();
    }

    function testWBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory wbtcConfig         = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold, 65_00);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        wbtcConfig.liquidationThreshold        = 60_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
    }

    function testcbBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory cbBTCConfig         = _findReserveConfigBySymbol(allConfigsBefore, 'cbBTC');

        assertEq(cbBTCConfig.liquidationThreshold, 70_00);
        assertEq(cbBTCConfig.ltv, 65_00);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        cbBTCConfig.liquidationThreshold        = 75_00;
        cbBTCConfig.ltv                         = 74_00;

        _validateReserveConfig(cbBTCConfig, allConfigsAfter);
    }

    function testExistingMorphoVault() public {
        MarketParams memory sUSDeVault =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_27MAR2025,
            oracle:          PT_27MAR2025_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        _assertMorphoCap(sUSDeVault, 200_000_000e18);

        executePayload(payload);

        _assertMorphoCap(sUSDeVault, 200_000_000e18, 400_000_000e18);

        skip(1 days);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(sUSDeVault);
        _assertMorphoCap(sUSDeVault, 400_000_000e18);
    }
}
