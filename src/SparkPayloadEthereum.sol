// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './AaveV3PayloadBase.sol';

import { Ethereum } from 'spark-address-registry/Ethereum.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

/**
 * @dev Base smart contract for Ethereum.
 * @author Phoenix Labs
 */
abstract contract SparkPayloadEthereum is
    AaveV3PayloadBase(IEngine(Ethereum.CONFIG_ENGINE))
{
    function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
        return IEngine.PoolContext({networkName: 'Ethereum', networkAbbreviation: 'Eth'});
    }
    function encodePayloadQueue(address _payload) internal pure returns (bytes memory) {
        address[] memory targets        = new address[](1);
        uint256[] memory values         = new uint256[](1);
        string[] memory signatures      = new string[](1);
        bytes[] memory calldatas        = new bytes[](1);
        bool[] memory withDelegatecalls = new bool[](1);

        targets[0]           = _payload;
        values[0]            = 0;
        signatures[0]        = 'execute()';
        calldatas[0]         = '';
        withDelegatecalls[0] = true;

        return abi.encodeCall(IL2BridgeExecutor.queue, (
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls
        ));
    }
}
