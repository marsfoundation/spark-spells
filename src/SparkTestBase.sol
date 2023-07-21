// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'aave-helpers/ProtocolV3TestBase.sol';

import { IDaiInterestRateStrategy }    from "./IDaiInterestRateStrategy.sol";
import { IDaiJugInterestRateStrategy } from "./IDaiJugInterestRateStrategy.sol";

contract SparkTestBase is ProtocolV3_0_1TestBase {

    struct DaiInterestStrategyValues {
        address vat;
        address pot;
        bytes32 ilk;
        uint256 baseRateConversion;
        uint256 borrowSpread;
        uint256 supplySpread;
        uint256 maxRate;
        uint256 performanceBonus;
    }

    struct DaiJugInterestStrategyValues {
        address vat;
        address jug;
        bytes32 ilk;
        uint256 baseRateConversion;
        uint256 borrowSpread;
        uint256 supplySpread;
        uint256 maxRate;
        uint256 performanceBonus;
    }

    function _writeStrategyConfig(string memory strategiesKey, address _strategy) internal override returns (string memory content) {
        try IDefaultInterestRateStrategy(_strategy).getBaseStableBorrowRate() {
            // Default IRS
            content = super._writeStrategyConfig(strategiesKey, _strategy);
        } catch {
            // DAI IRS
            string memory key = vm.toString(_strategy);

            IDaiInterestRateStrategy strategy = IDaiInterestRateStrategy(_strategy);

            vm.serializeUint(key, 'baseRateConversion', strategy.baseRateConversion());
            vm.serializeUint(key, 'borrowSpread',       strategy.borrowSpread());
            vm.serializeUint(key, 'supplySpread',       strategy.supplySpread());
            vm.serializeUint(key, 'maxRate',            strategy.maxRate());

            string memory object = vm.serializeUint(key, 'performanceBonus', strategy.performanceBonus());

            content = vm.serializeString(strategiesKey, key, object);
        }
    }

    function _validateDaiInterestRateStrategy(
        address interestRateStrategyAddress,
        address expectedStrategy,
        DaiInterestStrategyValues memory expectedStrategyValues
    ) internal view {
        IDaiInterestRateStrategy strategy = IDaiInterestRateStrategy(
            interestRateStrategyAddress
        );

        require(
            address(strategy) == expectedStrategy,
            '_validateDaiInterestRateStrategy() : INVALID_STRATEGY_ADDRESS'
        );

        require(
            strategy.vat() == expectedStrategyValues.vat,
            '_validateDaiInterestRateStrategy() : INVALID_VAT'
        );
        require(
            strategy.pot() == expectedStrategyValues.pot,
            '_validateDaiInterestRateStrategy() : INVALID_POT'
        );
        require(
            strategy.ilk() == expectedStrategyValues.ilk,
            '_validateDaiInterestRateStrategy() : INVALID_ILK'
        );
        require(
            strategy.baseRateConversion() == expectedStrategyValues.baseRateConversion,
            '_validateDaiInterestRateStrategy() : INVALID_BASE_RATE_CONVERSION'
        );
        require(
            strategy.borrowSpread() == expectedStrategyValues.borrowSpread,
            '_validateDaiInterestRateStrategy() : INVALID_BORROW_SPREAD'
        );
        require(
            strategy.supplySpread() == expectedStrategyValues.supplySpread,
            '_validateDaiInterestRateStrategy() : INVALID_SUPPLY_SPREAD'
        );
        require(
            strategy.maxRate() == expectedStrategyValues.maxRate,
            '_validateDaiInterestRateStrategy() : INVALID_MAX_RATE'
        );
        require(
            strategy.performanceBonus() == expectedStrategyValues.performanceBonus,
            '_validateDaiInterestRateStrategy() : INVALID_PERFORMANCE_BONUS'
        );
    }

    function _validateDaiJugInterestRateStrategy(
        address interestRateStrategyAddress,
        address expectedStrategy,
        DaiJugInterestStrategyValues memory expectedStrategyValues
    ) internal view {
        IDaiJugInterestRateStrategy strategy = IDaiJugInterestRateStrategy(
            interestRateStrategyAddress
        );

        require(
            address(strategy) == expectedStrategy,
            '_validateDaiInterestRateStrategy() : INVALID_STRATEGY_ADDRESS'
        );

        require(
            strategy.vat() == expectedStrategyValues.vat,
            '_validateDaiInterestRateStrategy() : INVALID_VAT'
        );
        require(
            strategy.jug() == expectedStrategyValues.jug,
            '_validateDaiInterestRateStrategy() : INVALID_JUG'
        );
        require(
            strategy.ilk() == expectedStrategyValues.ilk,
            '_validateDaiInterestRateStrategy() : INVALID_ILK'
        );
        require(
            strategy.baseRateConversion() == expectedStrategyValues.baseRateConversion,
            '_validateDaiInterestRateStrategy() : INVALID_BASE_RATE_CONVERSION'
        );
        require(
            strategy.borrowSpread() == expectedStrategyValues.borrowSpread,
            '_validateDaiInterestRateStrategy() : INVALID_BORROW_SPREAD'
        );
        require(
            strategy.supplySpread() == expectedStrategyValues.supplySpread,
            '_validateDaiInterestRateStrategy() : INVALID_SUPPLY_SPREAD'
        );
        require(
            strategy.maxRate() == expectedStrategyValues.maxRate,
            '_validateDaiInterestRateStrategy() : INVALID_MAX_RATE'
        );
        require(
            strategy.performanceBonus() == expectedStrategyValues.performanceBonus,
            '_validateDaiInterestRateStrategy() : INVALID_PERFORMANCE_BONUS'
        );
    }

    function _variableBorrowFlowAllCollaterals(
        ReserveConfig[] memory configs,
        IPool pool,
        address user
    )
        internal
    {
        for (uint256 i = 0; i < configs.length; i++) {
            ReserveConfig memory collateral = configs[i];

            if (
                !collateral.usageAsCollateralEnabled ||
                collateral.stableBorrowRateEnabled   ||
                collateral.isFrozen
            ) {
                console.log("\n\n\n");
                console.log("--------");
                console.log('SKIP: COLLATERAL_DISABLED_OR_STABLE %s', collateral.symbol);
                console.log("--------");
                continue;
            }

            console.log("\n\n\n");
            console.log("--------");
            console.log("COLLATERAL %s", collateral.symbol);
            console.log("--------");

            uint256 HUNDRED_MIL = 100_000_000 * 10 ** collateral.decimals;

            uint256 supplyCap
                = collateral.supplyCap == 0 ? type(uint256).max : collateral.supplyCap;

            // If supply cap is 0, deposit 100M, else limit to supply cap
            uint256 depositAmount = HUNDRED_MIL > supplyCap ? supplyCap : HUNDRED_MIL;

            _deposit(collateral, pool, user, depositAmount);

            for (uint256 j = 0; j < configs.length; j++) {
                ReserveConfig memory borrow = configs[j];

                if (!borrow.borrowingEnabled || borrow.isFrozen) {
                    console.log('\nSKIP: BORROWING_DISABLED %s', borrow.symbol);
                    continue;
                }

                console.log("\nBORROW", borrow.symbol);

                uint256 amount = 10 ** borrow.decimals;

                // Add some supply for user to borrow
                _deposit(borrow, pool, EOA, amount * 2);

                // Borrow one unit of borrow token
                this._borrow(borrow, pool, user, amount, false);
            }
        }
    }

    function sparkE2eTest(IPool pool, address user) public {
        ReserveConfig[] memory configs = _getReservesConfigs(pool);
        deal(user, 1000 ether);
        uint256 snapshot = vm.snapshot();
        _supplyWithdrawFlow(configs, pool, user);
        vm.revertTo(snapshot);
        _variableBorrowFlowAllCollaterals(configs, pool, user);
        vm.revertTo(snapshot);
    }

}
