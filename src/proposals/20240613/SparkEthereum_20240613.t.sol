// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

contract SparkEthereum_20240613 is SparkEthereumTestBase {

    address internal constant WEETH            = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant WEETH_PRICE_FEED = 0x1A6BDB22b9d7a454D20EAf12DB55D6B5F058183D;

    constructor() {
        id = '20240613';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testCollateralOnboarding() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        assertEq(allConfigsBefore.length, 9);

        _assertSupplyCapConfig({
            asset:            WEETH,
            max:              0,
            gap:              0,
            increaseCooldown: 0
        });

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        assertEq(allConfigsAfter.length, 10);

        ReserveConfig memory weeth = ReserveConfig({
            symbol:                  'weETH',
            underlying:               WEETH,
            aToken:                   address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            variableDebtToken:        address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            stableDebtToken:          address(0),  // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
            decimals:                 18,
            ltv:                      72_00,
            liquidationThreshold:     73_00,
            liquidationBonus:         110_00,
            liquidationProtocolFee:   10_00,
            reserveFactor:            15_00,
            usageAsCollateralEnabled: true,
            borrowingEnabled:         false,
            interestRateStrategy:     _findReserveConfigBySymbol(allConfigsAfter, 'weETH').interestRateStrategy,
            stableBorrowRateEnabled:  false,
            isPaused:                 false,
            isActive:                 true,
            isFrozen:                 false,
            isSiloed:                 false,
            isBorrowableInIsolation:  false,
            isFlashloanable:          false,
            supplyCap:                5_000,
            borrowCap:                0,
            debtCeiling:              50_000_000_00,  // In units of cents - conversion happens in the config engine
            eModeCategory:            0
        });

        _validateReserveConfig(weeth, allConfigsAfter);

        _validateInterestRateStrategy(
            weeth.interestRateStrategy,
            weeth.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.45e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.15e27,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0.05e27,
                variableRateSlope1:            0.15e27,
                variableRateSlope2:            3e27
            })
        );

        _validateAssetSourceOnOracle(poolAddressesProvider, WEETH, WEETH_PRICE_FEED);

        _assertSupplyCapConfig({
            asset:            WEETH,
            max:              50_000,
            gap:              5_000,
            increaseCooldown: 12 hours
        });
    }

}
