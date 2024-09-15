// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

interface ITolled {
    function kiss(address) external;
}

contract SparkEthereum_20240926Test is SparkEthereumTestBase {

    address internal constant CBBTC            = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant CBBTC_PRICE_FEED = 0x24C392CDbF32Cf911B258981a66d5541d85269ce;

    constructor() {
        id = '20240926';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20753858);  // Sep 15, 2024
        payload = deployPayload();

        // TODO remove this when actually tolled
        vm.prank(0x40C33e796be78148CeC983C2202335A0962d172A);
        ITolled(CBBTC_PRICE_FEED).kiss(Ethereum.SPARK_PROXY);

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testCollateralOnboarding() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        assertEq(allConfigsBefore.length, 9);

        _assertSupplyCapConfig({
            asset:            CBBTC,
            max:              0,
            gap:              0,
            increaseCooldown: 0
        });
        _assertBorrowCapConfig({
            asset:            CBBTC,
            max:              0,
            gap:              0,
            increaseCooldown: 0
        });

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        assertEq(allConfigsAfter.length, 10);

        ReserveConfig memory cbbtc = ReserveConfig({
            symbol:                  'cbBTC',
            underlying:               CBBTC,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 8,
            ltv:                      65_00,
            liquidationThreshold:     70_00,
            liquidationBonus:         108_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            20_00,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         true,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'cbBTC').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          true,
            supplyCap:                500,
            borrowCap:                50,
            debtCeiling:              0,
            eModeCategory:            0
        });

        _validateReserveConfig(cbbtc, allConfigsAfter);

        _validateInterestRateStrategy(
            cbbtc.interestRateStrategy,
            cbbtc.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.6e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.04e27,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.04e27,
                variableRateSlope2:            3e27
            })
        );

        _validateAssetSourceOnOracle(poolAddressesProvider, CBBTC, CBBTC_PRICE_FEED);

        _assertSupplyCapConfig({
            asset:            CBBTC,
            max:              3_000,
            gap:              500,
            increaseCooldown: 12 hours
        });
        _assertBorrowCapConfig({
            asset:            CBBTC,
            max:              500,
            gap:              50,
            increaseCooldown: 12 hours
        });
    }

    function testWBTCOffboarding() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wbtcBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');
        assertEq(wbtcBefore.liquidationThreshold, 75_00);

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

        wbtcBefore.liquidationThreshold = 70_00;
        _validateReserveConfig(wbtcBefore, allConfigsAfter);

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
