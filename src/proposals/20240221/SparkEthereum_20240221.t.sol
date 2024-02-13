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

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY  = 0x512AFEDCF6696d9707dCFECD4bdc73e9902e3c6A;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY  = 0x512AFEDCF6696d9707dCFECD4bdc73e9902e3c6A;  // TODO

    int256 public constant DAI_IRM_SPREAD =  0.013808977611475523600880000e27;  // TODO

    constructor() {
        id = '20240221';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*********************************/
        /*** DAI IRM Before Assertions ***/
        /*********************************/

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /********************************/
        /*** DAI IRM After Assertions ***/
        /********************************/

        ReserveConfig memory daiConfigAfter  = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');

        int256 potDsrApr = IRateSource(IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE()).getAPR();

        uint256 expectedDaiBaseVariableBorrowRate = uint256(potDsrApr + DAI_IRM_SPREAD);
        assertEq(expectedDaiBaseVariableBorrowRate, 0.062599141818649791361008000e27);  // TODO

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
