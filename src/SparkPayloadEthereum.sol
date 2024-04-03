// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import './AaveV3PayloadBase.sol';

import { Ethereum } from 'spark-address-registry/src/Ethereum.sol';

/**
 * @dev Base smart contract for a Aave v3.0.1 (compatible with 3.0.0) listing on Ethereum.
 * @author Phoenix Labs
 */
abstract contract SparkPayloadEthereum is
  AaveV3PayloadBase(IEngine(Ethereum.CONFIG_ENGINE))
{
  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Ethereum', networkAbbreviation: 'Eth'});
  }
}
