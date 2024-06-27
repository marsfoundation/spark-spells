// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { ICapAutomator } from 'lib/sparklend-cap-automator/src/interfaces/ICapAutomator.sol';
import { SparkPayloadEthereum, Ethereum } from 'src/SparkPayloadEthereum.sol';

/**
 * @title  Jul 11, 2024 Spark Ethereum Proposal
 * @notice Increase Capacity of weETH
 * @author Wonderland
 * Forum:  https://forum.makerdao.com/t/jun-27-2024-proposed-changes-to-spark-for-upcoming-spell/24552
 * Vote:   *TODO*
 */
contract SparkEthereum_20240711 is SparkPayloadEthereum {

    // TODO: Get address from registry
    address internal constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    function _postExecute()
        internal override
    {
        // Increase max supply cap to 200,000 weETH (Increase for 150,000 weETH)
        ICapAutomator(Ethereum.CAP_AUTOMATOR).setSupplyCapConfig({asset: WEETH, max: 200_000, gap: 5_000, increaseCooldown: 12 hours});
    }

}
