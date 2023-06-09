// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'aave-helpers/v3-config-engine/AaveV3PayloadBase.sol';

/**
 * @dev Base smart contract for a Aave v3.0.1 (compatible with 3.0.0) listing on Goerli.
 * @author Phoenix Labs
 */
abstract contract SparkPayloadGoerli is
  AaveV3PayloadBase(IEngine(0x862B1C4B6d07bc1f6810BD1eA19bb894B2645a92))
{
  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Goerli', networkAbbreviation: 'Gor'});
  }
}
