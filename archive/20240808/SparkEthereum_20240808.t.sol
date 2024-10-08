// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { Errors } from "sparklend-v1-core/contracts/protocol/libraries/helpers/Errors.sol";

interface IPotRateSource {
    function pot() external view returns (address);
}

interface IIRM {
    function RATE_SOURCE() external view returns (IPotRateSource);
}

interface PotLike {
    function drip() external;
    function file(bytes32 what, uint256 data) external;
}

interface IRateSource {
    function getAPR() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface ICappedFallbackRateSource is IRateSource {
    function source() external view returns (address);
    function lowerBound() external view returns (uint256);
    function upperBound() external view returns (uint256);
    function defaultRate() external view returns (uint256);
}

interface IKinkedIRM {
    function RATE_SOURCE() external view returns (address);
    function getVariableRateSlope1Spread() external view returns (uint256);
}

contract SparkEthereum_20240808Test is SparkEthereumTestBase {

    address public constant LST_SOURCE              = 0x08669C836F41AEaD03e3EF81a59f3b8e72EC417A;
    address public constant CAPPED_FALLBACK_WRAPPER = 0xaBc99f366D2bE1f4e5b8DFC0F561a751dd836246;

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x92af90912FD747aE836e0E9d5462A210EfE6A881;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0xC527A1B514796A6519f236dd906E73cab5aA2E71;

    address public constant OLD_WETH_INTEREST_RATE_STRATEGY = 0xE27c3f9d35e00ae48144b35DD157F72AaF36c77e;
    address public constant NEW_WETH_INTEREST_RATE_STRATEGY = 0x6fd32465a23aa0DBaE0D813B7157D8CB2b08Dae4;

    // Not a special number, the APR just happens to be 3.0%
    uint256 public constant LST_ORACLE_YIELD = 0.029967454605150944e18;

    uint256 public constant DAI_IRM_SPREAD = 0.009389740368586287841344000e27;

    constructor() {
        id = '20240808';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20499107);  // Aug 10, 2024
        payload = 0x85042d44894E08f81D70A2Ae568C09f907297dcb;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        vm.startPrank(Ethereum.PAUSE_PROXY);
        PotLike(Ethereum.POT).drip();
        PotLike(Ethereum.POT).file('dsr', 1000000001847694957439350562);
        vm.stopPrank();
    }

    function testLSTOracleDeployment() public {
        vm.prank(address(0));  // Whitelist allows address(0)
        assertEq(IRateSource(LST_SOURCE).getAPR(),   LST_ORACLE_YIELD);
        assertEq(IRateSource(LST_SOURCE).decimals(), 18);

        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).getAPR(),      LST_ORACLE_YIELD);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).decimals(),    18);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).source(),      LST_SOURCE);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).lowerBound(),  0.02e18);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).upperBound(),  0.055e18);
        assertEq(ICappedFallbackRateSource(CAPPED_FALLBACK_WRAPPER).defaultRate(), 0.03e18);

        assertEq(IKinkedIRM(NEW_WETH_INTEREST_RATE_STRATEGY).RATE_SOURCE(),                 CAPPED_FALLBACK_WRAPPER);
        assertEq(IKinkedIRM(NEW_WETH_INTEREST_RATE_STRATEGY).getVariableRateSlope1Spread(), 0);
    }

    function testDaiInterestRateUpdate() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');

        address rateSource = address(IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE());
        address pot = IPotRateSource(rateSource).pot();
        assertEq(pot, IIRM(OLD_DAI_INTEREST_RATE_STRATEGY).RATE_SOURCE().pot());  // Same pot as before

        uint256 potDsrApr = IRateSource(rateSource).getAPR();

        // Approx 6% APY
        assertEq(_getAPY(potDsrApr), 0.059999999999999999957390146e27);

        uint256 expectedDaiBaseVariableBorrowRate = potDsrApr + DAI_IRM_SPREAD;

        // Approx 7% APY
        assertEq(_getAPY(expectedDaiBaseVariableBorrowRate), 0.069999999999999999987440814e27);

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

    function testWethInterestRateUpdate() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WETH');

        assertEq(wethConfigBefore.interestRateStrategy, OLD_WETH_INTEREST_RATE_STRATEGY);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory wethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'WETH');

        uint256 expectedSlope1 = LST_ORACLE_YIELD * 10 ** 9;
        assertEq(expectedSlope1, 0.029967454605150944e27);

        _validateInterestRateStrategy(
            wethConfigAfter.interestRateStrategy,
            NEW_WETH_INTEREST_RATE_STRATEGY,
            InterestStrategyValues({
                addressesProvider:             address(poolAddressesProvider),
                optimalUsageRatio:             0.9e27,
                optimalStableToTotalDebtRatio: 0,
                baseStableBorrowRate:          expectedSlope1,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            expectedSlope1,  // Decimals are 27 instead of 18
                variableRateSlope2:            1.2e27
            })
        );
    }

    function testWBTCParamChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory wbtcConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfigBefore.ltv,              74_00);
        assertEq(wbtcConfigBefore.borrowingEnabled, true);

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        wbtcConfigBefore.ltv = 0;
        wbtcConfigBefore.borrowingEnabled = false;

        _validateReserveConfig(wbtcConfigBefore, allConfigsAfter);
    }

    function testWBTCDesiredActionsPrevented() public {
        IERC20(Ethereum.WBTC).approve(address(pool), type(uint256).max);

        // Can supply and borrow
        deal(Ethereum.WBTC, address(this), 100e8);
        pool.supply(Ethereum.WBTC, 50e8, address(this), 0);
        pool.borrow(Ethereum.WETH, 1e18, 2, 0, address(this));
        pool.borrow(Ethereum.WBTC, 5e8, 2, 0, address(this));

        executePayload(payload);

        // Cannot borrow other assets anymore
        vm.expectRevert(bytes(Errors.LTV_VALIDATION_FAILED));
        pool.borrow(Ethereum.WETH, 1e18, 2, 0, address(this));

        // Cannot borrow WBTC anymore
        vm.expectRevert(bytes(Errors.BORROWING_NOT_ENABLED));
        pool.borrow(Ethereum.WBTC, 1e8, 2, 0, address(this));

        // Can supply more
        pool.supply(Ethereum.WBTC, 25e8, address(this), 0);

        // Can repay loan
        pool.repay(Ethereum.WBTC, 3e8, 2, address(this));

        // Can withdraw WBTC
        pool.withdraw(Ethereum.WBTC, 5e8, address(this));
    }

}
