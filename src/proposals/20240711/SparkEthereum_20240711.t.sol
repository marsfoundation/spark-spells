// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

interface IPotRateSource {
    function pot() external view returns (address);
}

interface IIRM {
    function RATE_SOURCE() external view returns (IPotRateSource);
}

interface IRateSource {
    function getAPR() external view returns (int256);
}

interface PotLike {
    function drip() external;
    function file(bytes32 what, uint256 data) external;
}

contract SparkEthereum_20240711Test is SparkEthereumTestBase {

    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x5ae77aE8ec1B0F9a741C80A4Cdb876e6b5B619b9;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x92af90912FD747aE836e0E9d5462A210EfE6A881;

    int256 public constant DAI_IRM_SPREAD = 0.009302392683643256181504000e27;

    constructor() {
        id = '20240711';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20240487);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        vm.startPrank(Ethereum.PAUSE_PROXY);
        PotLike(Ethereum.POT).drip();
        PotLike(Ethereum.POT).file('dsr', 1000000002145441671308778766);
        vm.stopPrank();
    }

    function testCapIncrease() public {
        // Supply cap should be 50_000 WETH before
        _assertSupplyCapConfig({
            asset:            Ethereum.WEETH,
            max:              50_000,
            gap:              5000,
            increaseCooldown: 12 hours
        });

        executePayload(payload);

        // Supply cap should be 200_000 WETH after
        _assertSupplyCapConfig({
            asset:            Ethereum.WEETH,
            max:              200_000,
            gap:              5000,
            increaseCooldown: 12 hours
        });
    }

    function testDebtCeilingIncrease() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory weethConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'weETH');
        
        // Debt ceiling should be 50_000_000 DAI before
        assertEq(weethConfigBefore.debtCeiling, 50_000_000_00); // In units of cents - conversion happens in the config engine

        executePayload(payload);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory weethConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'weETH');

        // Debt ceiling should be 200_000_000 DAI after
        assertEq(weethConfigAfter.debtCeiling, 200_000_000_00); // In units of cents - conversion happens in the config engine

        // The rest of the configuration should remain the same
        weethConfigBefore.debtCeiling = weethConfigAfter.debtCeiling;
        _validateReserveConfig(weethConfigBefore, allConfigsAfter);
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

        int256 potDsrApr = IRateSource(rateSource).getAPR();

        // Approx 7% APY
        assertEq(_getAPY(uint256(potDsrApr)), 0.069999999999999999987440814e27);

        uint256 expectedDaiBaseVariableBorrowRate = uint256(potDsrApr + DAI_IRM_SPREAD);

        // Approx 8% APY
        assertEq(_getAPY(expectedDaiBaseVariableBorrowRate), 0.079999999999999999951590734e27);

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
}
