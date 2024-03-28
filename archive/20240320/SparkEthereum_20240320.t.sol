// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

interface IIRM {
    function RATE_SOURCE() external view returns (address);
}

interface IRateSource {
    function getAPR() external view returns (int256);
}

interface PotLike {
    function drip() external;
    function file(bytes32 what, uint256 data) external;
}

interface IOwnable {
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

contract SparkEthereum_20240320Test is SparkEthereumTestBase {

    address public constant META_MORPHO_VAULT              = 0x73e65DBD630f90604062f6E02fAb9138e713edD9;
    address public constant META_MORPHO_VAULT_OWNER        = 0xf1DB0D7f6aEc96d096f1b42d6B14440ca3d1c78b;
    address public constant OLD_DAI_INTEREST_RATE_STRATEGY = 0x7949a8Ef09c49506cCB1cB983317272dcf4170Dd;
    address public constant NEW_DAI_INTEREST_RATE_STRATEGY = 0x883b03288D1827066C57E5db96661aB994Ef3800;
    address public constant POT                            = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7;
    address public constant PAUSE_PROXY                    = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address public constant SPARK_PROXY                    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

    int256 public constant DAI_IRM_SPREAD = 0.008810629717531220974944000e27;

    constructor() {
        id = '20240320';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 19491194);  // March 22, 2024
        payload = 0x210DF2e1764Eb5491d41A62E296Ea39Ab56F9B6d;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        vm.startPrank(PAUSE_PROXY);
        PotLike(POT).drip();
        PotLike(POT).file('dsr', 1000000003875495717943815211);
        vm.stopPrank();
    }

    function testCapAutomatorConfiguration() public {
        _assertSupplyCapConfig({
            asset:            WBTC,
            max:              5_000,
            gap:              500,
            increaseCooldown: 12 hours
        });

        GovHelpers.executePayload(vm, payload, executor);

        _assertSupplyCapConfig({
            asset:            WBTC,
            max:              6_000,
            gap:              500,
            increaseCooldown: 12 hours
        });
    }

    function testInterestRateUpdate() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigBefore = _findReserveConfigBySymbol(allConfigsBefore, 'DAI');

        assertEq(daiConfigBefore.interestRateStrategy, OLD_DAI_INTEREST_RATE_STRATEGY);

        GovHelpers.executePayload(vm, payload, executor);

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);

        ReserveConfig memory daiConfigAfter = _findReserveConfigBySymbol(allConfigsAfter, 'DAI');

        address rateSource = IIRM(daiConfigAfter.interestRateStrategy).RATE_SOURCE();
        assertEq(rateSource, IIRM(OLD_DAI_INTEREST_RATE_STRATEGY).RATE_SOURCE());  // Same rate source as before

        int256 potDsrApr = IRateSource(rateSource).getAPR();

        // Approx 13% APY
        assertEq(_getAPY(uint256(potDsrApr)), 0.129999999999999999958580159e27);

        uint256 expectedDaiBaseVariableBorrowRate = uint256(potDsrApr + DAI_IRM_SPREAD);
        assertEq(expectedDaiBaseVariableBorrowRate, 0.131028262678607377469040000e27);

        // Approx 14% APY
        assertEq(_getAPY(expectedDaiBaseVariableBorrowRate), 0.139999999999999999983521905e27);

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

    function testVaultOwnership() public {
        IOwnable vault = IOwnable(META_MORPHO_VAULT);

        assertEq(vault.owner(),        META_MORPHO_VAULT_OWNER);
        assertEq(vault.pendingOwner(), SPARK_PROXY);

        GovHelpers.executePayload(vm, payload, executor);

        assertEq(vault.owner(),        SPARK_PROXY);
        assertEq(vault.pendingOwner(), address(0));
    }

}
