// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IERC20 } from "src/interfaces/IERC20.sol";

import { IAToken }           from "lib/aave-v3-core/contracts/interfaces/IAToken.sol";
import { IPoolDataProvider } from "lib/aave-v3-core/contracts/interfaces/IPoolDataProvider.sol";

import { SparkEthereum_20231129 } from './SparkEthereum_20231129.sol';

contract SparkEthereum_20231129Test is SparkEthereumTestBase {

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x41709f51E59ddbEbF37cE95257b2E4f2884a45F8;
    address constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x7d8f2210FAD012E7d260C3ddBeCaCfd48277455F;

    IPoolDataProvider dataProvider = IPoolDataProvider(0xFc21d6d146E6086B8359705C8b28512a983db0cb);

    uint256 constant OLD_SUPPLY_SPREAD = 0;
    uint256 constant NEW_SUPPLY_SPREAD = 0.005e27;

    constructor() {
        id = '20231129';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 18_622_106);
        payload = 0x68a075249fA77173b8d1B92750c9920423997e2B;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        /****************************************************/
        /*** Dai Interest Rate Strategy Before Assertions ***/
        /****************************************************/

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');
        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        IDaiInterestRateStrategy oldStrategy
            = IDaiInterestRateStrategy(OLD_DAI_INTEREST_RATE_STRATEGY);

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

    function test_assetLiabilityDiff() public {
        uint256 startingTimestamp = block.timestamp;

        uint256 startDiff = _getAssetLiabilityDiff(DAI);

        assertEq(startDiff, 221_232.428488870663797097 ether);

        // Take snapshot before simulating protocol activity
        uint256 snapshot = vm.snapshot();

        // Simulate 1 year of protocol activity
        for (uint256 i = 0; i < (24 * 365); i++) {
            vm.warp(startingTimestamp + i * 1 hours);
            _supply(DAI, 1e18);
        }

        // Demonstrate that the asset liability diff would continue to increase over time
        assertEq(_getAssetLiabilityDiff(DAI),             2_330_389.091939282711804580 ether);
        assertEq(_getAssetLiabilityDiff(DAI) - startDiff, 2_109_156.663450412048007483 ether);

        // Warp back to original timestamp and snapshot
        vm.warp(startingTimestamp);
        vm.revertTo(snapshot);

        // Execute spell
        GovHelpers.executePayload(vm, payload, executor);

        ( uint256 supplyRate1, uint256 variableBorrowRate1 ) = _getRates(DAI);

        // Diff should be small since utilization is almost 100%
        assertEq(supplyRate1,         0.046330401155582341410874849e27);
        assertEq(variableBorrowRate1, 0.053790164207174267760128000e27);

        // Supply a small amount of DAI to update rates
        _supply(DAI, 1e18);

        ( uint256 supplyRate2, uint256 variableBorrowRate2 ) = _getRates(DAI);

        // Show that rates have updated
        // Diff is small since utilization is almost 100%
        assertEq(supplyRate2,         0.051078367754112897710958380e27);
        assertEq(variableBorrowRate2, 0.053790164207174267760128000e27);

        // Supply rate change is slightly less than supplySpread update because of utilization
        assertEq(variableBorrowRate2 - variableBorrowRate1, 0);
        assertEq(supplyRate2 - supplyRate1,                 0.004747966598530556300083531e27);

        // Make sure that diff is the same as start of test
        assertApproxEqAbs(_getAssetLiabilityDiff(DAI), startDiff, 1);

        // Simulate 1 year of protocol activity
        for (uint256 i = 0; i < (24 * 365); i++) {
            vm.warp(startingTimestamp + i * 1 hours);
            _supply(DAI, 1e18);
        }

        // Demonstrate that the asset liability diff would continue to increase over time
        // but at a lower rate. This is because the discrepancy itself is accruing value.
        assertEq(_getAssetLiabilityDiff(DAI),             232_910.005786463415880304 ether);
        assertEq(_getAssetLiabilityDiff(DAI) - startDiff,  11_677.577297592752083207 ether);
    }

    function _getAssetLiabilityDiff(address asset) internal view returns (uint256 diff) {
        ( , uint256 accruedToTreasuryScaled,,,,,,,,,, ) = dataProvider.getReserveData(asset);

        ( address aToken,, ) = dataProvider.getReserveTokensAddresses(asset);

        uint256 totalDebt         = dataProvider.getTotalDebt(asset);
        uint256 totalLiquidity    = IERC20(asset).balanceOf(aToken);
        uint256 scaledLiabilities = IAToken(aToken).scaledTotalSupply() + accruedToTreasuryScaled;

        uint256 assets      = totalLiquidity + totalDebt;
        uint256 liabilities = scaledLiabilities * pool.getReserveNormalizedIncome(asset) / 1e27;

        diff = assets - liabilities;
    }

    function _getRates(address asset)
        internal view returns (uint256 supplyRate, uint256 variableBorrowRate)
    {
        ( ,,,,, supplyRate, variableBorrowRate,,,,, ) = dataProvider.getReserveData(asset);
    }

    function _supply(address asset, uint256 amount) internal {
        address user = makeAddr("user");
        deal(asset, user, amount);
        vm.startPrank(user);
        IERC20(asset).approve(address(pool), amount);
        pool.supply(asset, amount, user, 0);
        vm.stopPrank();
    }

}
