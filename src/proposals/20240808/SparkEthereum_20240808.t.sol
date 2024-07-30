// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

interface IRateSource {
    function getAPR() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface ICappedFallbackRateSource is IRateSource {
    function source() external view returns (address);
    function lowerBound() external view returns (uint256);
    function upperBound() external view returns (uint256);
    function defaultRate() external view returns (uint256);
}

interface IKinkedIRM {
    function RATE_SOURCE() external view returns (address);
    function getVariableRateSlope1Spread() external view returns (uint256);
}

contract SparkEthereum_20240808Test is SparkEthereumTestBase {

    address public constant LST_SOURCE              = 0x08669C836F41AEaD03e3EF81a59f3b8e72EC417A;
    address public constant CAPPED_FALLBACK_WRAPPER = 0xaBc99f366D2bE1f4e5b8DFC0F561a751dd836246;

    address public constant OLD_WETH_INTEREST_RATE_STRATEGY = 0xE27c3f9d35e00ae48144b35DD157F72AaF36c77e;
    address public constant NEW_WETH_INTEREST_RATE_STRATEGY = 0x6fd32465a23aa0DBaE0D813B7157D8CB2b08Dae4;

    uint256 public constant LST_ORACLE_YIELD = 0.028604597378813033e18;

    constructor() {
        id = '20240808';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20421368);  // Jul 30, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testOracleDeploy() public {
        // Not a special number, the APR just happens to be 2.8%
        vm.prank(address(0));  // Whitelist allows address(0)
        assertEq(IRateSource(LST_SOURCE).getAPR(),   LST_ORACLE_YIELD);
        assertEq(IRateSource(LST_SOURCE).decimals(), 18);

        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).getAPR(),      LST_ORACLE_YIELD);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).decimals(),    18);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).source(),      LST_SOURCE);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).lowerBound(),  0.02e18);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).upperBound(),  0.055e18);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).defaultRate(), 0.03e18);

        assertEq(IKinkedIRM(NEW_WETH_INTEREST_RATE_STRATEGY).RATE_SOURCE(),                 CAPPED_FALLBACK_WRAPPER);
        assertEq(IKinkedIRM(NEW_WETH_INTEREST_RATE_STRATEGY).getVariableRateSlope1Spread(), 0);
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');

        assertEq(wethConfigBefore.interestRateStrategy, OLD_WETH_INTEREST_RATE_STRATEGY);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory wethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WETH');

        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            NEW_WETH_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          LST_ORACLE_YIELD * 10 ** 9,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0.028604597378813033e27,  // Decimals are 27 instead of 18
                variableRateSlope2:            1.2e27
            })
        );
    }

}
