// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import { SparkPayloadEthereum, Address } from '../../SparkPayloadEthereum.sol';

interface IForwarder {
    function execute(address payload) external;
}

/**
 * @title  September 27, 2023 Spark Ethereum Proposal - Activate Gnosis Chain instance
 * @author Phoenix Labs
 * @dev    This proposal activates the Gnosis Chain instance of Spark Lend
 * Forum:  https://forum.makerdao.com/t/proposal-for-activation-of-gnosis-chain-instance/22098
 * Vote:   TODO
 */
contract SparkEthereum_20230927 is SparkPayloadEthereum {

    using Address for address;

    address public constant GNOSIS_FORWARDER = 0x44f993EAe9a420Df9ffa5263c55f6C8eF46c0340;
    address public constant GNOSIS_PAYLOAD   = 0x1472B7d120ab62D60f60e1D804B3858361c3C475;

    function _postExecute() internal override {
        GNOSIS_FORWARDER.functionDelegateCall(
            abi.encodeWithSelector(
                IForwarder.execute.selector,
                GNOSIS_PAYLOAD
            )
        );
    }

}
