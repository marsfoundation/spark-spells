// // SPDX-License-Identifier: AGPL-3.0
// pragma solidity ^0.8.10;

// import '../../SparkTestBase.sol';

// import { Ownable } from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/Ownable.sol';
// import { BaseAdminUpgradeabilityProxy } from 'aave-v3-core/contracts/dependencies/openzeppelin/upgradeability/BaseAdminUpgradeabilityProxy.sol';

// import { SparkGoerli_20230816 } from './SparkGoerli_20230816.sol';

// contract SparkGoerli_20230816Test is SparkGoerliTestBase {

//     address constant internal PAUSE_PROXY = 0x5DCdbD3cCF9B09EAAD03bc5f50fA2B3d3ACA0121;

//     address public constant MCD_VAT = 0xB966002DDAa2Baf48369f5015329750019736031;
//     address public constant MCD_JUG = 0xC90C99FE9B5d5207A03b9F28A6E8A19C0e558916;
//     address public constant MCD_POT = 0x50672F0a14B40051B65958818a7AcA3D54Bd81Af;

//     address public constant DAI_INTEREST_RATE_STRATEGY_OLD
//         = 0x7f44e1c1dE70059D7cc483378BEFeE2a030CE247;

//     address public constant DAI_INTEREST_RATE_STRATEGY_NEW
//         = 0x70659BcA22A2a8BB324A526a8BB919185d3ecEBC;

//     bytes32 public constant SPARK_ILK = "DIRECT-SPARK-DAI";

//     IPool public constant POOL = IPool(0x26ca51Af4506DE7a6f0785D20CD776081a05fF6d);

//     address public constant POOL_IMPLEMENTATION_OLD = 0xF1E57711Eb5F897b415de1aEFCB64d9BAe58D312;
//     address public constant POOL_IMPLEMENTATION_NEW = 0xe7EA57b22D5F496BF9Ca50a7830547b704Ecb91F;

//     constructor() {
//         id = '20230816';
//     }

//     function setUp() public {
//         vm.createSelectFork(getChain('goerli').rpcUrl, 9_500_235);
//         payload = 0x13176Ad78eC3d2b6E32908B019D0F772EC0b4dFd;

//         // This will be done in the main spell (simulate it here)
//         loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
//         vm.prank(PAUSE_PROXY);
//         Ownable(address(poolAddressesProvider)).transferOwnership(address(executor));
//     }

//     function testSpellSpecifics() public {

//         /*************************/
//         /*** Before Assertions ***/
//         /*************************/

//         ReserveConfig[] memory configsBefore = createConfigurationSnapshot('', POOL);

//         _validateDaiJugInterestRateStrategy(
//             _findReserveConfigBySymbol(configsBefore, 'DAI').interestRateStrategy,
//             DAI_INTEREST_RATE_STRATEGY_OLD,
//             DaiJugInterestStrategyValues({
//                 vat:                MCD_VAT,
//                 jug:                MCD_JUG,
//                 ilk:                SPARK_ILK,
//                 baseRateConversion: 1e27,
//                 borrowSpread:       0,
//                 supplySpread:       0,
//                 maxRate:            0.75e27,
//                 performanceBonus:   0
//             })
//         );
//         assertEq(_findReserveConfigBySymbol(configsBefore, 'sDAI').isFrozen, true);
//         vm.prank(address(poolAddressesProvider));
//         assertEq(BaseAdminUpgradeabilityProxy(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_OLD);

//         /***********************/
//         /*** Execute Payload ***/
//         /***********************/

//         GovHelpers.executePayload(vm, payload, executor);

//         /************************/
//         /*** After Assertions ***/
//         /************************/

//         ReserveConfig[] memory configsAfter = createConfigurationSnapshot('', POOL);

//         _validateDaiInterestRateStrategy(
//             _findReserveConfigBySymbol(configsAfter, 'DAI').interestRateStrategy,
//             DAI_INTEREST_RATE_STRATEGY_NEW,
//             DaiInterestStrategyValues({
//                 vat:                MCD_VAT,
//                 pot:                MCD_POT,
//                 ilk:                SPARK_ILK,
//                 baseRateConversion: 1e27,
//                 borrowSpread:       0,
//                 supplySpread:       0,
//                 maxRate:            0.75e27,
//                 performanceBonus:   0
//             })
//         );
//         assertEq(_findReserveConfigBySymbol(configsAfter, 'sDAI').isFrozen, false);
//         vm.prank(address(poolAddressesProvider));
//         assertEq(BaseAdminUpgradeabilityProxy(payable(address(pool))).implementation(), POOL_IMPLEMENTATION_NEW);
//     }

// }
