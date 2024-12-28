// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './AaveV3PayloadBase.sol';

import { Base }     from 'spark-address-registry/Base.sol';
import { Ethereum } from 'spark-address-registry/Ethereum.sol';
import { Gnosis }   from 'spark-address-registry/Gnosis.sol';

import { IExecutor } from 'spark-gov-relay/src/interfaces/IExecutor.sol';

import { OptimismForwarder } from "xchain-helpers/forwarders/OptimismForwarder.sol";
import { AMBForwarder }      from "xchain-helpers/forwarders/AMBForwarder.sol";

import { SparkLiquidityLayerHelpers } from './libraries/SparkLiquidityLayerHelpers.sol';

/**
 * @dev Base smart contract for Ethereum.
 * @author Phoenix Labs
 */
abstract contract SparkPayloadEthereum is
    AaveV3PayloadBase(IEngine(Ethereum.CONFIG_ENGINE))
{

    address public immutable payloadBase;
    address public immutable payloadGnosis;

    function execute() public override {
        super.execute();

        if (payloadBase != address(0)) {
            OptimismForwarder.sendMessageL1toL2({
                l1CrossDomain: OptimismForwarder.L1_CROSS_DOMAIN_BASE,
                target:        Base.SPARK_RECEIVER,
                message:       _encodePayloadQueue(payloadBase),
                gasLimit:      1_000_000
            });
        }
        if (payloadGnosis != address(0)) {
            AMBForwarder.sendMessageEthereumToGnosisChain({
                target:   Gnosis.AMB_EXECUTOR,
                message:  _encodePayloadQueue(payloadGnosis),
                gasLimit: 1_000_000
            });
        }
    }

    function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
        return IEngine.PoolContext({networkName: 'Ethereum', networkAbbreviation: 'Eth'});
    }

    function _encodePayloadQueue(address _payload) internal pure returns (bytes memory) {
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

        return abi.encodeCall(IExecutor.queue, (
            targets,
            values,
            signatures,
            calldatas,
            withDelegatecalls
        ));
    }

    function _onboardAaveToken(address token, uint256 depositMax, uint256 depositSlope) internal {
        SparkLiquidityLayerHelpers.onboardAaveToken(
            Ethereum.ALM_RATE_LIMITS,
            token,
            depositMax,
            depositSlope
        );
    }

    function _onboardERC4626Vault(address vault, uint256 depositMax, uint256 depositSlope) internal {
        SparkLiquidityLayerHelpers.onboardERC4626Vault(
            Ethereum.ALM_RATE_LIMITS,
            vault,
            depositMax,
            depositSlope
        );
    }

}
