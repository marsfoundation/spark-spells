// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

interface IIRM {
    function RATE_SOURCE() external view returns (address);
}

interface IRateSource {
    function getAPR() external view returns (int256);
}

contract SparkEthereum_20240221Test is SparkEthereumTestBase {

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x512AFEDCF6696d9707dCFECD4bdc73e9902e3c6A;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x3C4B090b5b479402e2270C66461D6a62B2054198;

    int256 public constant DAI_IRM_SPREAD = 0.016060808179122167684448000e27;

    uint256 public constant OLD_WSTETH_SUPPLY_CAP = 800_000;
    uint256 public constant NEW_WSTETH_SUPPLY_CAP = 1_200_000;

    constructor() {
        id = '20240221';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19233093);  // Feb 15, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore    = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        ReserveConfig memory wstethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'wstETH');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);
        assertEq(wstethConfigBefore.supplyCap, OLD_WSTETH_SUPPLY_CAP);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');

        address rateSource = IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE();
        assertEq(rateSource, IIRM(OLD_DAI_INTEREST_RATE_STRATEGY).RATE_SOURCE());  // Same rate source as before

        int256 potDsrApr = IRateSource(rateSource).getAPR();

        uint256 expectedDaiBaseVariableBorrowRate = uint256(potDsrApr + DAI_IRM_SPREAD);
        assertEq(expectedDaiBaseVariableBorrowRate, 0.064850972386296435444576000e27);

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

        wstethConfigBefore.supplyCap = NEW_WSTETH_SUPPLY_CAP;
        _validateReserveConfig(wstethConfigBefore, allConfigsAfter);
    }

}
