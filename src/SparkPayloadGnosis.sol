// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './AaveV3PayloadBase.sol';

/**
 * @dev Base smart contract for a Aave v3.0.1 (compatible with 3.0.0) listing on Ethereum.
 * @author Phoenix Labs
 */
abstract contract SparkPayloadGnosis is
  AaveV3PayloadBase(IEngine(0x36eddc380C7f370e5f05Da5Bd7F970a27f063e39))
{
  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Gnosis Chain', networkAbbreviation: 'Gno'});
  }
}
