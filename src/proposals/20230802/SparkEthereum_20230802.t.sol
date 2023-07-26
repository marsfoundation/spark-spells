// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { IPool }     from "aave-v3-core/contracts/interfaces/IPool.sol";
import { DataTypes } from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

import { DefaultReserveInterestRateStrategy }
    from "aave-v3-core/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol";

import { ReserveConfiguration }
    from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";

import { ReserveConfig }    from 'aave-helpers/ProtocolV3TestBase.sol';
import { TestWithExecutor } from 'aave-helpers/GovHelpers.sol';

import { InterestStrategyValues, SparkTestBase, IERC20 } from '../../SparkTestBase.sol';
import { IDaiInterestRateStrategy }                      from '../../IDaiInterestRateStrategy.sol';

import { SparkEthereum_20230802 } from './SparkEthereum_20230802.sol';

interface IPotLike {
    function drip() external returns (uint256);
    function dsr() external view returns (uint256);
    function file(bytes32, uint256) external;
}

contract SparkEthereum_20230802Test is SparkTestBase, TestWithExecutor {

    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant MCD_VAT = 0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B;
    address public constant MCD_JUG = 0x19c0976f590D67707E62397C87829d896Dc0f1F1;
    address public constant MCD_POT = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;

    address public constant EXECUTOR    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;
    address public constant PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;

    address public constant POOL_ADDRESSES_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;

    address public constant DAI_INTEREST_RATE_STRATEGY_OLD
        = 0x9f9782880dd952F067Cad97B8503b0A3ac0fb21d;

    address public constant DAI_INTEREST_RATE_STRATEGY_NEW
        = 0x191E97623B1733369290ee5d018d0B068bc0400D;

    bytes32 public constant SPARK_ILK = "DIRECT-SPARK-DAI";

    uint256 internal constant RAY = 1e27;

    IPool public constant POOL = IPool(0xC13e21B648A5Ee794902342038FF3aDAB66BE987);

    // 80% utilization = Optimal usage ratio for WETH
    // NOTE: Using mock address for aToken so balance is not used in calculation
    DataTypes.CalculateInterestRatesParams public rateParams =
        DataTypes.CalculateInterestRatesParams({
            unbacked:                0,
            liquidityAdded:          200_000e18,  // 200k + 800k = 1m total liquidity
            liquidityTaken:          0,
            totalStableDebt:         0,
            totalVariableDebt:       800_000e18,
            averageStableBorrowRate: 0,
            reserveFactor:           0,
            reserve:                 DAI,
            aToken:                  makeAddr("mock-aToken")
        });

    SparkEthereum_20230802 public payload;

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 17_740_300);

        _selectPayloadExecutor(EXECUTOR);

        payload = new SparkEthereum_20230802();
    }

    function testSpellExecution() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot(
            'pre-Spark-Ethereum-20230802',
            POOL
        );

        /********************************************/
        /*** DAI Strategy Before State Assertions ***/
        /********************************************/

        _validateDaiInterestRateStrategy(
            _findReserveConfigBySymbol(allConfigsBefore, 'DAI').interestRateStrategy,
            DAI_INTEREST_RATE_STRATEGY_OLD,
            DaiInterestStrategyValues({
                vat:                MCD_VAT,
                pot:                MCD_POT,
                ilk:                SPARK_ILK,
                baseRateConversion: RAY,
                borrowSpread:       0,
                supplySpread:       0,
                maxRate:            0.75e27,
                performanceBonus:   0
            })
        );

        /****************************************/
        /*** Execute Payload and Diff Reports ***/
        /****************************************/

        _executePayload(address(payload));

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot(
            'post-Spark-Ethereum-20230802',
            POOL
        );

        diffReports(
            'pre-Spark-Ethereum-20230802',
            'post-Spark-Ethereum-20230802'
        );

        /*******************************************/
        /*** DAI Strategy After State Assertions ***/
        /*******************************************/

        _validateDaiJugInterestRateStrategy(
            _findReserveConfigBySymbol(allConfigsAfter, 'DAI').interestRateStrategy,
            DAI_INTEREST_RATE_STRATEGY_NEW,
            DaiJugInterestStrategyValues({
                vat:                MCD_VAT,
                jug:                MCD_JUG,
                ilk:                SPARK_ILK,
                baseRateConversion: RAY,
                borrowSpread:       0,
                supplySpread:       0,
                maxRate:            0.75e27,
                performanceBonus:   0
            })
        );

        /***************************************/
        /*** DAI Collateral State Assertions ***/
        /***************************************/

        ReserveConfig memory DAI_EXPECTED_CONFIG = _findReserveConfig(allConfigsAfter, DAI);

        DAI_EXPECTED_CONFIG.liquidationThreshold = 1_00;
        DAI_EXPECTED_CONFIG.ltv                  = 1_00;

        // DAI is still technically enabled as collateral, just with a 0.01% liquidation threshold
        // This is because DAI is being supplied by Maker, and AAVE prevents liquidation threshold
        // being set to zero with active suppliers.
        DAI_EXPECTED_CONFIG.usageAsCollateralEnabled = true;

        _validateReserveConfig(DAI_EXPECTED_CONFIG, allConfigsAfter);

        /****************************************/
        /*** WETH Collateral State Assertions ***/
        /****************************************/

        ReserveConfig memory WETH_EXPECTED_CONFIG = _findReserveConfig(allConfigsAfter, WETH);

        WETH_EXPECTED_CONFIG.reserveFactor = 5_00;

        _validateReserveConfig(WETH_EXPECTED_CONFIG, allConfigsAfter);

        _validateInterestRateStrategy(
            WETH_EXPECTED_CONFIG.interestRateStrategy,
            WETH_EXPECTED_CONFIG.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             POOL_ADDRESSES_PROVIDER,
                optimalUsageRatio:             0.80e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          0.03e27,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0.01e27,
                variableRateSlope1:            0.03e27,
                variableRateSlope2:            0.80e27
            })
        );
    }

    function testSpellExecution_manualAssertions() public {
        IDaiInterestRateStrategy daiStrategy = IDaiInterestRateStrategy(
            DAI_INTEREST_RATE_STRATEGY_OLD
        );

        /********************************************/
        /*** DAI Strategy Before State Assertions ***/
        /********************************************/

        daiStrategy.recompute();

        uint256 startingDsr           = IPotLike(MCD_POT).dsr();
        uint256 startingAnnualizedDsr = _getAnnualizedDsr(startingDsr);

        // ETH-C rate at ~3.14% (currently equals annualized DSR)
        uint256 stabilityFee = 0.031401763155165655148976000e27;

        ( ,, uint256 borrowRate ) = daiStrategy.calculateInterestRates(rateParams);

        assertEq(startingDsr,               1.000000000995743377573746041e27);
        assertEq(daiStrategy.getBaseRate(), stabilityFee);
        assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);
        assertEq(borrowRate,                startingAnnualizedDsr);

        uint256 updatedDsr = 1.000000001585489599188229325e27;  // ~5% annualized

        IPotLike(MCD_POT).drip();
        vm.prank(PAUSE_PROXY);
        IPotLike(MCD_POT).file('dsr', updatedDsr);

        daiStrategy.recompute();

        uint256 updatedAnnualizedDsr = _getAnnualizedDsr(updatedDsr);

        ( ,, borrowRate ) = daiStrategy.calculateInterestRates(rateParams);

        // Demonstrate that old strategy is directly affected by DSR change
        assertEq(IPotLike(MCD_POT).dsr(),   updatedDsr);
        assertEq(daiStrategy.getBaseRate(), 0.049999999999999999993200000e27);  // ~5%
        assertEq(daiStrategy.getBaseRate(), updatedAnnualizedDsr);
        assertEq(borrowRate,                updatedAnnualizedDsr);

        // Go back to starting state before execution
        IPotLike(MCD_POT).drip();
        vm.prank(PAUSE_PROXY);
        IPotLike(MCD_POT).file('dsr', startingDsr);

        daiStrategy.recompute();

        ( ,, borrowRate ) = daiStrategy.calculateInterestRates(rateParams);

        assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);  // Back to 3.14%
        assertEq(borrowRate,                startingAnnualizedDsr);

        /*****************/
        /*** Execution ***/
        /*****************/

        _executePayload(address(payload));

        /*******************************************/
        /*** DAI Strategy After State Assertions ***/
        /*******************************************/

        daiStrategy = IDaiInterestRateStrategy(DAI_INTEREST_RATE_STRATEGY_NEW);

        daiStrategy.recompute();

        ( ,, borrowRate ) = daiStrategy.calculateInterestRates(rateParams);

        // Starting state is in line with DSR since ETH-C SFBR matches DSR
        assertEq(IPotLike(MCD_POT).dsr(),   startingDsr);
        assertEq(daiStrategy.getBaseRate(), stabilityFee);
        assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);
        assertEq(borrowRate,                stabilityFee);

        // Change DSR to ~5% annualized
        IPotLike(MCD_POT).drip();
        vm.prank(PAUSE_PROXY);
        IPotLike(MCD_POT).file('dsr', updatedDsr);

        daiStrategy.recompute();

        // Demonstrate that new strategy is NOT affected by DSR change
        assertEq(IPotLike(MCD_POT).dsr(),   updatedDsr);             // DSR is 5% annualized
        assertEq(daiStrategy.getBaseRate(), stabilityFee);           // Still 3.14%
        assertEq(daiStrategy.getBaseRate(), startingAnnualizedDsr);  // Still 3.14%
        assertEq(borrowRate,                stabilityFee);           // Still 3.14%

        /****************************************/
        /*** WETH Collateral State Assertions ***/
        /****************************************/

        ReserveConfig[] memory configs = createConfigurationSnapshot('', POOL);

        DefaultReserveInterestRateStrategy wethStrategy = DefaultReserveInterestRateStrategy(
            _findReserveConfig(configs, WETH).interestRateStrategy
        );

        // NOTE: This is not actually necessary since balance isn't used, added for clarity.
        rateParams.reserve = WETH;

        ( ,, borrowRate ) = wethStrategy.calculateInterestRates(rateParams);

        // 80% utilization
        assertEq(borrowRate, 0.04e27);

        // Update to 90% utilization
        rateParams.liquidityAdded    = 100_000e18;
        rateParams.totalVariableDebt = 900_000e18;

        ( ,, borrowRate ) = wethStrategy.calculateInterestRates(rateParams);

        // 90% utilization - 50% excess * 80% variable rate slope 2 = 40% + existing 4%
        assertEq(borrowRate, 0.44e27);

        /*****************/
        /*** E2E Tests ***/
        /*****************/

        sparkE2eTest(POOL, makeAddr("newUser"));
    }

    function testSpellExecution_liquidations() public {
        address lp = makeAddr("lp");

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        address liquidator1 = makeAddr("liquidator1");
        address liquidator2 = makeAddr("liquidator2");
        ReserveConfig[] memory configs = createConfigurationSnapshot('', POOL);

        ReserveConfig memory dai  = _findReserveConfig(configs, DAI);
        ReserveConfig memory weth = _findReserveConfig(configs, WETH);

        // Ensure WETH liquidity
        _deposit(weth, POOL, lp, 1_000_000e18);

        // Setup some positions ahead of time that can later be liquidated
        // Position is 350 ETH so ~700k
        _deposit(dai, POOL, user2, 1_000_000e18);
        this._borrow(weth, POOL, user2, 350e18, false);

        _deposit(dai,  POOL, user3, 1_000_000e18);
        _deposit(weth, POOL, user3, 1_000e18);
        this._borrow(weth, POOL, user3, 1_000e18, false);

        _executePayload(address(payload));

        // --- Test 1 - Cannot borrow more than small amount against DAI ---

        // Deposit 1m
        _deposit(dai, POOL, user1, 1_000_000e18);

        // Should only be able to borrow small amounts of ETH
        // 1m * 1% = $10k = ~5.2 ETH (with price at ~1.9k / ETH)
        this._borrow(weth, POOL, user1, 5.2e18, false);

        // Cannot borrow more
        vm.expectRevert(bytes('36'));	// COLLATERAL_CANNOT_COVER_NEW_BORROW
        this._borrow(weth, POOL, user1, 0.1e18, false);

        // --- Test 2 - Can liquidate any single position that was previously setup ---

        // Liquidate the position setup previously
        assertEq(IERC20(dai.underlying).balanceOf(liquidator1), 0);
        assertEq(IERC20(dai.aToken).balanceOf(user2),           1_000_000e18);

        _liquidate(dai, weth, POOL, liquidator1, user2, 350e18);

        // Liquidator should get about 700k DAI (with price at ~$1,950 / ETH)
        assertApproxEqAbs(IERC20(dai.underlying).balanceOf(liquidator1), 682_500e18, 5_000e18);

        // User can keep remainder
        assertApproxEqAbs(IERC20(dai.aToken).balanceOf(user2), 317_500e18, 10_000e18);

        // --- Test 3 - Liquidate multi-collateralized position ---

        // We can fully liquidate the DAI position which now contributes almost nothing to HF
        assertEq(IERC20(dai.underlying).balanceOf(liquidator2),  0);
        assertEq(IERC20(weth.underlying).balanceOf(liquidator2), 0);
        assertEq(IERC20(dai.aToken).balanceOf(user3),            1_000_000e18);
        assertEq(IERC20(weth.aToken).balanceOf(user3),           1_000e18);
        
        // Can only liquidate about half the debt, but this will make the position healthy
        // Can only do half because there is only 1m DAI collateral for 2m in debt
        _liquidate(dai, weth, POOL, liquidator2, user3, 1_000e18);

        assertApproxEqAbs(IERC20(dai.underlying).balanceOf(liquidator2), 1_000_000e18, 50_000e18);

        // Some WETH is leftover because the liquidation call was limited by the amount of DAI available
        assertApproxEqAbs(IERC20(weth.underlying).balanceOf(liquidator2), 500e18, 50e18);
        assertApproxEqAbs(IERC20(dai.aToken).balanceOf(user3),            0,      1);
    }

    function _getAnnualizedDsr(uint256 dsr) internal pure returns (uint256) {
        return (dsr - RAY) * 365 days;
    }

}
