// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

interface IIRM {
    function RATE_SOURCE() external view returns (address);
}

interface IRateSource {
    function getAPR() external view returns (int256);
}

interface PotLike {
    function drip() external;
    function file(bytes32 what, uint256 data) external;
}

contract SparkEthereum_20240516Test is SparkEthereumTestBase {

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0xE9905C2dCf64F3fBAeE50a81D1844339FC77e812;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x5ae77aE8ec1B0F9a741C80A4Cdb876e6b5B619b9;

    int256 public constant DAI_IRM_SPREAD = 0.009216655128763325601840000e27;

    constructor() {
        id = '20240516';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19859567);  // May 13, 2024
        payload = 0x901E4450f01ae1A2615E384b9104888Cb9Cb02FF;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        vm.startPrank(Ethereum.PAUSE_PROXY);
        PotLike(Ethereum.POT).drip();
        PotLike(Ethereum.POT).file('dsr', 1000000002440418608258400030);
        vm.stopPrank();
    }

    function testDaiInterestRateUpdate() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');

        address rateSource = IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE();
        assertEq(rateSource, IIRM(OLD_DAI_INTEREST_RATE_STRATEGY).RATE_SOURCE());  // Same rate source as before

        int256 potDsrApr = IRateSource(rateSource).getAPR();

        // Approx 8% APY
        assertEq(_getAPY(uint256(potDsrApr)), 0.079999999999999999951590734e27);

        uint256 expectedDaiBaseVariableBorrowRate = uint256(potDsrApr + DAI_IRM_SPREAD);
        assertEq(expectedDaiBaseVariableBorrowRate, 0.086177696358800228947920000e27);

        // Approx 9% APY
        assertEq(_getAPY(expectedDaiBaseVariableBorrowRate), 0.089999999999999999975356909e27);

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
    }

}
