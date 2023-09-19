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
    function executeAffirmation(bytes memory message) external;
    function validatorContract() external view returns (address);
}

interface IL2BridgeExecutor {
    function queue(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls
    ) external;
    function execute(uint256 index) external;
    function getActionsSetCount() external view returns (uint256);
    function getDelay() external view returns (uint256);
}

interface IValidatorContract {
    function validatorList() external view returns (address[] memory);
    function requiredSignatures() external view returns (uint256);
}

contract SparkEthereum_20230927Test is SparkEthereumTestBase {

    address constant L1_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS = 0x4C36d2919e407f0Cc2Ee3c993ccF8ac26d9CE64e;
    address constant L2_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS = 0x75Df5AF045d91108662D8080fD1FEFAd6aA0bb59;
    address constant AMB_BRIDGE_EXECUTOR = 0xc4218C1127cB24a0D6c1e7D25dc34e10f2625f5A;
    address constant GNOSIS_POOL = 0x2Dae5307c5E3FD1CF5A72Cb6F698f915860607e0;

    constructor() {
        id = '20230927';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl);
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
        bytes memory messageToRelay = abi.encodeWithSelector(
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
                messageToRelay,
                IAMB(L1_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS).maxGasPerTx()
            )
        );
        GovHelpers.executePayload(vm, payload, executor);
    }

    function testCrossChainE2E() public {
        // Queue up the message on L1 (Ethereum)
        vm.recordLogs();
        GovHelpers.executePayload(vm, payload, executor);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("UserRequestForAffirmation(bytes32,bytes)");
        bytes memory messageToRelay;
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.topics[0] == topic) {
                messageToRelay = removeFirst64Bytes(log.data);

                break;
            }
        }
        if (messageToRelay.length == 0) {
            revert('No message to relay');
        }

        // Switch to Gnosis Chain fork
        vm.createSelectFork(getChain('gnosis_chain').rpcUrl, 30028657);

        // Simulate Gnosis Chain authorized validators signing the message
        IValidatorContract validatorContract = IValidatorContract(IAMB(L2_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS).validatorContract());
        address[] memory validators = validatorContract.validatorList();
        uint256 requiredSignatures = validatorContract.requiredSignatures();
        for (uint256 i = 0; i < requiredSignatures; i++) {
            assertEq(IL2BridgeExecutor(AMB_BRIDGE_EXECUTOR).getActionsSetCount(), 0);   // Check if payload execution has been queued
            vm.prank(validators[i]);
            IAMB(L2_AMB_CROSS_DOMAIN_MESSENGER_ADDRESS).executeAffirmation(messageToRelay);
        }
        assertEq(IL2BridgeExecutor(AMB_BRIDGE_EXECUTOR).getActionsSetCount(), 1);       // Action was queued
        
        // Permissionless logic to execute the queued payload after 2 day security delay
        assertEq(IL2BridgeExecutor(AMB_BRIDGE_EXECUTOR).getDelay(), 2 days);
        skip(2 days);
        assertEq(IPool(GNOSIS_POOL).getReservesList().length, 0);
        IL2BridgeExecutor(AMB_BRIDGE_EXECUTOR).execute(0);
        assertEq(IPool(GNOSIS_POOL).getReservesList().length, 4);   // Use as proxy for spell executing
    }

    function removeFirst64Bytes(bytes memory inputData) public pure returns (bytes memory) {
        bytes memory returnValue = new bytes(inputData.length - 64);
        for (uint256 i = 0; i < inputData.length - 64; i++) {
            returnValue[i] = inputData[i + 64];
        }
        return returnValue;
    }

}
