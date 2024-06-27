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
            _assertSupplyCapConfig({
                asset:            WEETH,
                max:              50_000,
                gap:              5000,
                increaseCooldown: 12 hours
            });

            executePayload(payload);

            _assertSupplyCapConfig({
                asset:            WEETH,
                max:              200_000,
                gap:              5000,
                increaseCooldown: 12 hours
            });
    }


}
