// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { DssSpellAction } from "spells-mainnet/src/DssSpell.sol";

import { MainnetController } from 'lib/spark-alm-controller/src/MainnetController.sol';

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface IWardLike {
    function rely(address) external;
}

contract SparkEthereum_20241107TestBase is SparkEthereumTestBase {

    address constant FREEZER = 0x298b375f24CeDb45e936D7e21d6Eb05e344adFb5;  // Gov. facilitator multisig
    address constant RELAYER = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

    MainnetController constant mainnetController = MainnetController(Ethereum.ALM_CONTROLLER);

    constructor() {
        id = '20241107';
    }

    function setUp() public virtual {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 21044602);  // Oct 25, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}

contract PostSpellExecutionTestBase is SparkEthereum_20241107TestBase {

    function setUp() public override {
        super.setUp();

        address spell = address(new DssSpellAction());

        vm.etch(Ethereum.PAUSE_PROXY, spell.code);

        DssSpellAction(Ethereum.PAUSE_PROXY).execute();

        executePayload(payload);
    }

}
