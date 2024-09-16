// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

interface ITolled {
    function kiss(address) external;
}

contract SparkEthereum_20240926Test is SparkEthereumTestBase {

    address internal constant CBBTC            = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant CBBTC_PRICE_FEED = 0xb9ED698c9569c5abea716D1E64c089610a3768B6;

    constructor() {
        id = '20240926';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20761848);  // Sep 16, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testCollateralOnboarding() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        assertEq(allConfigsBefore.length, 10);

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

        assertEq(allConfigsAfter.length, 11);

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

}
