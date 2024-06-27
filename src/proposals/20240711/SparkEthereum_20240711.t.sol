// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

contract SparkEthereum_20240711Test is SparkEthereumTestBase {

    // TODO: Get address from registry
    address internal constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    constructor() {
        id = '20240711';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20185330);
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testCapIncrease() public {
        // Supply cap should be 50_000 WETH before
        _assertSupplyCapConfig({
            asset:            WEETH,
            max:              50_000,
            gap:              5000,
            increaseCooldown: 12 hours
        });

        executePayload(payload);

        // Supply cap should be 200_000 WETH after
        _assertSupplyCapConfig({
            asset:            WEETH,
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
}
