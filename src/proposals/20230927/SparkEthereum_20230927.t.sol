// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { SparkEthereum_20230927 } from './SparkEthereum_20230927.sol';

interface IAMB {
    function requireToPassMessage(
        address _contract,
        bytes memory _data,
        uint256 _gas
    ) external returns (bytes32);
    function maxGasPerTx() external view returns (uint256);
}

interface IL2BridgeExecutor {
    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external;
}

contract SparkEthereum_20230927Test is SparkEthereumTestBase {

    address constant L1_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS = 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;
    address constant AMB_BRIDGE_EXECUTOR = 0xc4218C1127cB24a0D6c1e7D25dc34e10f2625f5A;

    constructor() {
        id = '20230927';
    }

    function setUp() public {
        //vm.createSelectFork(getChain('mainnet').rpcUrl);
        vm.createSelectFork("http://127.0.0.1:8545");
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testRelay() public {
        address[] memory targets = new address[](1);
        targets[0] = SparkEthereum_20230927(payload).GNOSIS_PAYLOAD();
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = 'execute()';
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = '';
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;
        bytes memory queue = abi.encodeWithSelector(
            IL2BridgeExecutor.queue.selector,
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls
        );

        vm.expectCall(
            L1_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS,
            abi.encodeWithSelector(
                IAMB.requireToPassMessage.selector,
                AMB_BRIDGE_EXECUTOR,
                queue,
                IAMB(L1_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS).maxGasPerTx()
            )
        );
        GovHelpers.executePayload(vm, payload, executor);
    }

}
