// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import 'aave-helpers/ProtocolV3TestBase.sol';

import { IDaiInterestRateStrategy }    from "./IDaiInterestRateStrategy.sol";
import { IDaiJugInterestRateStrategy } from "./IDaiJugInterestRateStrategy.sol";

contract SparkTestBase is ProtocolV3TestBase {

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

    function _liquidate(
        ReserveConfig memory collateral,
        ReserveConfig memory debt,
        IPool pool,
        address liquidator,
        address user,
        uint256 amount
    ) internal {
        vm.startPrank(liquidator);
        deal(debt.underlying, liquidator, amount);
        IERC20(debt.underlying).approve(address(pool), amount);
        console.log('LIQUIDATION_CALL: Collateral: %s, Debt: %s, Amount: %s', collateral.symbol, debt.symbol, amount);
        pool.liquidationCall(collateral.underlying, debt.underlying, user, amount, false);
        vm.stopPrank();
    }

}
