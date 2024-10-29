// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { DssSpellAction } from "spells-mainnet/src/DssSpell.sol";

contract SparkEthereum_20241107Test is SparkEthereumTestBase {

    constructor() {
        id = '20241107';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 21071612);  // Oct 29, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);

        // Maker Core spell execution
        skip(1 hours);  // office hours restriction in maker core spell
        address spell = address(new DssSpellAction());
        vm.etch(Ethereum.PAUSE_PROXY, spell.code);
        DssSpellAction(Ethereum.PAUSE_PROXY).execute();
    }
    
}
