// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { DssSpellAction } from "spells-mainnet/src/DssSpell.sol";

contract SparkEthereum_20241107Test is SparkEthereumTestBase {

    address internal constant PT_26DEC2024_PRICE_FEED  = 0x81E5E28F33D314e9211885d6f0F4080E755e4595;
    address internal constant PT_SUSDE_26DEC2024       = 0xEe9085fC268F6727d5D4293dBABccF901ffDCC29;

    address internal constant PT_27MAR2025_PRICE_FEED  = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address internal constant PT_SUSDE_27MAR2025       = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;

    address public constant OLD_WETH_INTEREST_RATE_STRATEGY = 0x6fd32465a23aa0DBaE0D813B7157D8CB2b08Dae4;
    address public constant NEW_WETH_INTEREST_RATE_STRATEGY = 0xf4268AeC16d13446381F8a2c9bB05239323756ca;

    constructor() {
        id = '20241107';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 21071612);  // Oct 29, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        // Maker Core spell execution
        skip(1 hours);  // office hours restriction in maker core spell
        address spell = address(new DssSpellAction());
        vm.etch(Ethereum.PAUSE_PROXY, spell.code);
        DssSpellAction(Ethereum.PAUSE_PROXY).execute();
    }

    function testWBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wbtcConfig = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold,   70_00);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        wbtcConfig.liquidationThreshold   = 65_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
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

        _assertMorphoCap(ptUsde26Dec, 100_000_000e18);
        _assertMorphoCap(ptUsde27Mar, 100_000_000e18);

        executePayload(payload);

        _assertMorphoCap(ptUsde26Dec, 100_000_000e18, 250_000_000e18);
        _assertMorphoCap(ptUsde27Mar, 100_000_000e18, 150_000_000e18);

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        skip(1 days);

        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptUsde26Dec);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptUsde27Mar);

        _assertMorphoCap(ptUsde26Dec, 250_000_000e18);
        _assertMorphoCap(ptUsde27Mar, 150_000_000e18);
    }

    function testWethInterestRateUpdate() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');

        assertEq(wethConfigBefore.interestRateStrategy, OLD_WETH_INTEREST_RATE_STRATEGY);

        uint256 expectedOldSlope1 = 0.028564144275278442e27;
        InterestStrategyValues memory values = InterestStrategyValues({
            addressesProvider:             address(poolAddressesProvider),
            optimalUsageRatio:             0.9e27,
            optimalStableToTotalDebtRatio: 0,
            baseStableBorrowRate:          expectedOldSlope1,
            stableRateSlope1:              0,
            stableRateSlope2:              0,
            baseVariableBorrowRate:        0,
            variableRateSlope1:            expectedOldSlope1,
            variableRateSlope2:            1.2e27
        });
        _validateInterestRateStrategy(
            wethConfigBefore.interestRateStrategy,
            OLD_WETH_INTEREST_RATE_STRATEGY,
            values
        );

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory wethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WETH');

        uint256 expectedSlope1 = expectedOldSlope1 - 0.005e27;
        assertEq(expectedSlope1, 0.023564144275278442e27);

        values.baseStableBorrowRate = expectedSlope1;
        values.variableRateSlope1   = expectedSlope1;
        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            NEW_WETH_INTEREST_RATE_STRATEGY,
            values
        );
    }

    function testWSTETHBorrowCapUpdate() public {
        _assertBorrowCapConfig({
            asset:            Ethereum.WSTETH,
            max:              3_000,
            gap:              100,
            increaseCooldown: 12 hours
        });

        executePayload(payload);

        _assertBorrowCapConfig({
            asset:            Ethereum.WSTETH,
            max:              10_000,
            gap:              2_000,
            increaseCooldown: 12 hours
        });
    }
    
}
