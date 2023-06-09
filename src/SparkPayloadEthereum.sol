// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'aave-helpers/v3-config-engine/AaveV3PayloadBase.sol';

/**
 * @dev Base smart contract for a Aave v3.0.1 (compatible with 3.0.0) listing on Ethereum.
 * @author Phoenix Labs
 */
abstract contract SparkPayloadEthereum is
  AaveV3PayloadBase(IEngine(0x3254F7cd0565aA67eEdC86c2fB608BE48d5cCd78))
{
  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Ethereum', networkAbbreviation: 'Eth'});
  }
}
