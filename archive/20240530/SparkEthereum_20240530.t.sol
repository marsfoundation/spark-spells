// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';

contract SparkEthereum_20240530Test is SparkEthereumTestBase {

    address public constant STABLECOINS_IRM = 0x4Da18457A76C355B74F9e4A944EcC882aAc64043;

    address public constant GNOSIS_PAYLOAD = 0x4e77714b90b470Bef30613908FAd307Ca96A811a;

    Domain       mainnet;
    GnosisDomain gnosis;

    constructor() {
        id = '20240530';
    }

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        gnosis  = new GnosisDomain(getChain('gnosis_chain'), mainnet);

        mainnet.rollFork(19962401);  // May 27, 2024
        gnosis.rollFork(34161350);   // May 27, 2024

        mainnet.selectFork();

        payload = 0x7bcDd1c8641F8a0Ef98572427FDdD8c26D642256;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testMarketConfigChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory usdcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDC');
        assertEq(usdcConfigBefore.isSiloed, true);

        ReserveConfig memory usdtConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'USDT');
        assertEq(usdtConfigBefore.isSiloed, true);

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');
        IDefaultInterestRateStrategy wethOldInterestRateStrategy = IDefaultInterestRateStrategy(
            wethConfigBefore.interestRateStrategy
        );
        _validateInterestRateStrategy(
            address(wethOldInterestRateStrategy),
            address(wethOldInterestRateStrategy),
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             wethOldInterestRateStrategy.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: wethOldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.028e27,
                stableRateSlope1:              wethOldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              wethOldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        wethOldInterestRateStrategy.getBaseVariableBorrowRate(),
                variableRateSlope1:            0.028e27,
                variableRateSlope2:            wethOldInterestRateStrategy.getVariableRateSlope2()
            })
        );

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        uint256 dsrPlusOnePercent = 0.086961041230036903346080000e27;

        InterestStrategyValues memory usdIRMValues = InterestStrategyValues({
            addressesProvider:             address(poolAddressesProvider),
            optimalUsageRatio:             0.95e27,
            optimalStableToTotalDebtRatio: 0,
            baseStableBorrowRate:          dsrPlusOnePercent,
            stableRateSlope1:              0,
            stableRateSlope2:              0,
            baseVariableBorrowRate:        0,
            variableRateSlope1:            dsrPlusOnePercent,
            variableRateSlope2:            0.15e27
        });

        ReserveConfig memory usdcConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDC');
        usdcConfigBefore.isSiloed = false;
        usdcConfigBefore.interestRateStrategy = STABLECOINS_IRM;
        _validateReserveConfig(usdcConfigBefore, allConfigsAfter);
        _validateInterestRateStrategy(
            usdcConfigAfter.interestRateStrategy,
            usdcConfigAfter.interestRateStrategy,
            usdIRMValues
        );

        ReserveConfig memory usdtConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'USDT');
        usdtConfigBefore.isSiloed = false;
        usdtConfigBefore.interestRateStrategy = STABLECOINS_IRM;
        _validateReserveConfig(usdtConfigBefore, allConfigsAfter);
        _validateInterestRateStrategy(
            usdtConfigAfter.interestRateStrategy,
            usdtConfigAfter.interestRateStrategy,
            usdIRMValues
        );

        ReserveConfig memory wethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WETH');
        wethConfigBefore.interestRateStrategy = wethConfigAfter.interestRateStrategy;
        _validateReserveConfig(wethConfigBefore, allConfigsAfter);
        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            wethConfigAfter.interestRateStrategy,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             wethOldInterestRateStrategy.OPTIMAL_USAGE_RATIO(),
                optimalStableToTotalDebtRatio: wethOldInterestRateStrategy.OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO(),
                baseStableBorrowRate:          0.025e27,
                stableRateSlope1:              wethOldInterestRateStrategy.getStableRateSlope1(),
                stableRateSlope2:              wethOldInterestRateStrategy.getStableRateSlope2(),
                baseVariableBorrowRate:        wethOldInterestRateStrategy.getBaseVariableBorrowRate(),
                variableRateSlope1:            0.025e27,
                variableRateSlope2:            wethOldInterestRateStrategy.getVariableRateSlope2()
            })
        );
    }

    function testGnosisSpellExecution() public {
        executePayload(payload);

        gnosis.selectFork();

        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getActionsSetCount(), 4);

        gnosis.relayFromHost(true);
        skip(2 days);

        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getActionsSetCount(), 5);
        
        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getMinimumDelay(), 8 hours);
        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getDelay(),        2 days);
        IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).execute(4);
        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getMinimumDelay(), 0);
        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getDelay(),        0);
    }

    function testMorphoSupplyCapUpdates() public {
        MarketParams memory susde1 = MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: Ethereum.SUSDE,
            oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        });
        MarketParams memory susde2 = MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: Ethereum.SUSDE,
            oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        _assertMorphoCap(susde1, 200_000_000e18);
        _assertMorphoCap(susde2, 50_000_000e18);

        executePayload(payload);

        _assertMorphoCap(susde1, 200_000_000e18, 400_000_000e18);
        _assertMorphoCap(susde2, 50_000_000e18,  100_000_000e18);

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        skip(1 days);

        // These are permissionless (call coming from the test contract)
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(susde1);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(susde2);

        _assertMorphoCap(susde1, 400_000_000e18);
        _assertMorphoCap(susde2, 100_000_000e18);
    }

}
