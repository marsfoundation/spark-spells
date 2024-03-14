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

contract SparkEthereum_20240308Test is SparkEthereumTestBase {

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x3C4B090b5b479402e2270C66461D6a62B2054198;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x7949a8Ef09c49506cCB1cB983317272dcf4170Dd;
    address public constant POT                            = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;
    address public constant PAUSE_PROXY                    = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    int256 public constant DAI_IRM_SPREAD = 0.008658062782674090146928000e27;

    constructor() {
        id = '20240308';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19390540);
        payload = 0xFc72De9b361dB85F1d126De9cac51A1aEe8Ce126;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        vm.startPrank(PAUSE_PROXY);
        PotLike(POT).drip();
        PotLike(POT).file('dsr', 1000000004431822129783699001);
        vm.stopPrank();
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');

        address rateSource = IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE();
        assertEq(rateSource, IIRM(OLD_DAI_INTEREST_RATE_STRATEGY).RATE_SOURCE());  // Same rate source as before

        int256 potDsrApr = IRateSource(rateSource).getAPR();

        uint256 expectedDaiBaseVariableBorrowRate = uint256(potDsrApr + DAI_IRM_SPREAD);
        assertEq(expectedDaiBaseVariableBorrowRate, 0.148420005467532821842464000e27);

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
