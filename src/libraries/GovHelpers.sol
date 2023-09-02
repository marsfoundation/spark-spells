// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5 <0.9.0;

import {Vm} from 'forge-std/Vm.sol';

/**
 * @dev Mock contract which allows performing a delegatecall to `execute`
 * Intended to be used as replacement for L2 admins/executors to mock governance/gnosis execution.
 */
contract MockExecutor {
    /**
     * @notice Non-standard functionality used to skip governance and just execute a payload.
     */
    function execute(address payload) public {
      (bool success, ) = payload.delegatecall(abi.encodeWithSignature('execute()'));
      require(success, 'PROPOSAL_EXECUTION_FAILED');
    }
  }


library GovHelpers {

  function executePayload(Vm vm, address payloadAddress, address executor) internal {
      MockExecutor mockExecutor = new MockExecutor();
      vm.etch(executor, address(mockExecutor).code);
      MockExecutor(executor).execute(payloadAddress);
  }

}
