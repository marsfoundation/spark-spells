// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20231129 } from './SparkEthereum_20231129.sol';

contract SparkEthereum_20231129Test is SparkEthereumTestBase {

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x41709f51E59ddbEbF37cE95257b2E4f2884a45F8;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x7d8f2210FAD012E7d260C3ddBeCaCfd48277455F;

    uint256 public constant OLD_SUPPLY_SPREAD = 0;
    uint256 public constant NEW_SUPPLY_SPREAD = 0.005e27;

    constructor() {
        id = '20231129';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18_615_540);
        payload = address(new SparkEthereum_20231129());

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /****************************************************/
        /*** Dai Interest Rate Strategy Before Assertions ***/
        /****************************************************/

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        IDaiInterestRateStrategy oldStrategy = IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY);

        assertEq(oldStrategy.supplySpread(), OLD_SUPPLY_SPREAD);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        /***************************************************/
        /*** Dai Interest Rate Strategy After Assertions ***/
        /***************************************************/

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');
        assertEq(daiConfigAfter.interestRateStrategy, NEW_DAI_INTEREST_RATE_STRATEGY);

        _validateDaiInterestRateStrategy(
            daiConfigAfter.interestRateStrategy,
            NEW_DAI_INTEREST_RATE_STRATEGY,
            DaiInterestStrategyValues({
                vat:                oldStrategy.vat(),
                pot:                oldStrategy.pot(),
                ilk:                oldStrategy.ilk(),
                baseRateConversion: oldStrategy.baseRateConversion(),
                borrowSpread:       oldStrategy.borrowSpread(),
                supplySpread:       NEW_SUPPLY_SPREAD,
                maxRate:            oldStrategy.maxRate(),
                performanceBonus:   oldStrategy.performanceBonus()
            })
        );
    }

}
