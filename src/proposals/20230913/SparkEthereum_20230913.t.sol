// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20230913 } from './SparkEthereum_20230913.sol';

contract SparkEthereum_20230913Test is SparkEthereumTestBase {

    uint128 public constant OLD_FLASHLOAN_PREMIUM_TOTAL = 9;
    uint128 public constant NEW_FLASHLOAN_PREMIUM_TOTAL = 0;
    uint256 public constant OLD_BORROW_SPREAD           = 0;
    uint256 public constant NEW_BORROW_SPREAD           = 0.005e27;

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x41709f51E59ddbEbF37cE95257b2E4f2884a45F8;

    constructor() {
        id = '20230913';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {

        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /*************************************************/
        /*** FLASHLOAN_PREMIUM_TOTAL Before Assertions ***/
        /*************************************************/

        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), OLD_FLASHLOAN_PREMIUM_TOTAL);

        /****************************************************/
        /*** Dai Interest Rate Strategy Before Assertions ***/
        /****************************************************/

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /************************************************/
        /*** FLASHLOAN_PREMIUM_TOTAL After Assertions ***/
        /************************************************/

        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), NEW_FLASHLOAN_PREMIUM_TOTAL);

        /***************************************************/
        /*** Dai Interest Rate Strategy After Assertions ***/
        /***************************************************/

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');
        assertEq(daiConfigAfter.interestRateStrategy, NEW_DAI_INTEREST_RATE_STRATEGY);

        _validateDaiInterestRateStrategy(
            daiConfigAfter.interestRateStrategy,
            NEW_DAI_INTEREST_RATE_STRATEGY,
            DaiInterestStrategyValues({
                vat:                IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY).vat(),
                pot:                IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY).pot(),
                ilk:                IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY).ilk(),
                baseRateConversion: IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY).baseRateConversion(),
                borrowSpread:       NEW_BORROW_SPREAD,
                supplySpread:       IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY).supplySpread(),
                maxRate:            IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY).maxRate(),
                performanceBonus:   IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY).performanceBonus()
            })
        );
    }
}
