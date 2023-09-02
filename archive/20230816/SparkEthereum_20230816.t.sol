// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20230816 } from './SparkEthereum_20230816.sol';

interface IOwnableLike {
    function transferOwnership(address newOwner) external;
}

contract SparkEthereum_20230816Test is SparkEthereumTestBase {

    address constant internal PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    address public constant MCD_VAT = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address public constant MCD_JUG = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;
    address public constant MCD_POT = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;

    address public constant DAI_INTEREST_RATE_STRATEGY_OLD
        = 0x191E97623B1733369290ee5d018d0B068bc0400D;

    address public constant DAI_INTEREST_RATE_STRATEGY_NEW
        = 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;

    bytes32 public constant SPARK_ILK = "DIRECT-SPARK-DAI";

    IPool public constant POOL = IPool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);

    address public constant POOL_IMPLEMENTATION_OLD = 0x62DA45546A0F87b23941FFE5CA22f9D2A8fa7DF3;
    address public constant POOL_IMPLEMENTATION_NEW = 0x8115366Ca7Cf280a760f0bC0F6Db3026e2437115;

    constructor() {
        id = '20230816';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 17_892_780);
        payload = 0x60cC45DaB5F0B17789C77d5FE990f1aD80e9DD65;

        // This will be done in the main spell (simulate it here)
        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
        vm.prank(PAUSE_PROXY);
        IOwnableLike(address(poolAddressesProvider)).transferOwnership(address(executor));
    }

    function testSpellSpecifics() public {

        /*************************/
        /*** Before Assertions ***/
        /*************************/

        ReserveConfig[] memory configsBefore = createConfigurationSnapshot('', POOL);

        _validateDaiJugInterestRateStrategy(
            _findReserveConfigBySymbol(configsBefore, 'DAI').interestRateStrategy,
            DAI_INTEREST_RATE_STRATEGY_OLD,
            DaiJugInterestStrategyValues({
                vat:                MCD_VAT,
                jug:                MCD_JUG,
                ilk:                SPARK_ILK,
                baseRateConversion: 1e27,
                borrowSpread:       0,
                supplySpread:       0,
                maxRate:            0.75e27,
                performanceBonus:   0
            })
        );
        assertEq(_findReserveConfigBySymbol(configsBefore, 'sDAI').isFrozen, true);
        vm.prank(address(poolAddressesProvider));
        assertEq(IProxyLike(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_OLD);

        /***********************/
        /*** Execute Payload ***/
        /***********************/

        GovHelpers.executePayload(vm, payload, executor);

        /************************/
        /*** After Assertions ***/
        /************************/

        ReserveConfig[] memory configsAfter = createConfigurationSnapshot('', POOL);

        _validateDaiInterestRateStrategy(
            _findReserveConfigBySymbol(configsAfter, 'DAI').interestRateStrategy,
            DAI_INTEREST_RATE_STRATEGY_NEW,
            DaiInterestStrategyValues({
                vat:                MCD_VAT,
                pot:                MCD_POT,
                ilk:                SPARK_ILK,
                baseRateConversion: 1e27,
                borrowSpread:       0,
                supplySpread:       0,
                maxRate:            0.75e27,
                performanceBonus:   0
            })
        );
        assertEq(_findReserveConfigBySymbol(configsAfter, 'sDAI').isFrozen, false);
        vm.prank(address(poolAddressesProvider));
        assertEq(IProxyLike(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_NEW);
    }

}
