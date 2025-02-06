// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IERC20 }   from 'forge-std/interfaces/IERC20.sol';
import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { SparkPayloadEthereum, Ethereum } from "../../SparkPayloadEthereum.sol";

import { Arbitrum } from 'spark-address-registry/Arbitrum.sol';
import { Base }     from 'spark-address-registry/Base.sol';

import { AllocatorBuffer } from 'dss-allocator/src/AllocatorBuffer.sol';
import { AllocatorVault }  from 'dss-allocator/src/AllocatorVault.sol';

interface IOptimismTokenBridge {
    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

interface IArbitrumTokenBridge {
    function outboundTransfer(
        address l1Token,
        address to,
        uint256 amount,
        uint256 maxGas,
        uint256 gasPriceBid,
        bytes calldata data
    ) external payable returns (bytes memory res);
}

/**
 * @title  Feb 20, 2025 Spark Ethereum Proposal
 * @notice Spark Liquidity Layer: Onboard Arbitrum One, Mint 100m USDS worth of sUSDS into Base
 *         SparkLend: Increase weETH supply cap parameters
 * @author Phoenix Labs
 * Forum:  TODO
 * Vote:   TODO
 */
contract SparkEthereum_20250220 is SparkPayloadEthereum {

    uint256 internal constant USDS_MINT_AMOUNT             = 300_000_000e18;
    uint256 internal constant SUSDS_DEPOSIT_AMOUNT         = 200_000_000e18;
    uint256 internal constant SUSDS_BASE_BRIDGE_AMOUNT     = 100_000_000e18;
    uint256 internal constant USDS_ARBITRUM_BRIDGE_AMOUNT  = 100_000_000e18;

    constructor() {
        // TODO actual payloads
        PAYLOAD_BASE     = address(0);
        PAYLOAD_ARBITRUM = address(0);
    }

    function _postExecute() internal override {
        // --- Send USDS and sUSDS to Base and Arbitrum ---

        // Mint USDS and sUSDS
        AllocatorVault(Ethereum.ALLOCATOR_VAULT).draw(USDS_MINT_AMOUNT);
        AllocatorBuffer(Ethereum.ALLOCATOR_BUFFER).approve(Ethereum.USDS, address(this), USDS_MINT_AMOUNT);
        IERC20(Ethereum.USDS).transferFrom(Ethereum.ALLOCATOR_BUFFER, address(this), USDS_MINT_AMOUNT);
        IERC20(Ethereum.USDS).approve(Ethereum.SUSDS, SUSDS_DEPOSIT_AMOUNT);
        uint256 susdsShares = IERC4626(Ethereum.SUSDS).deposit(SUSDS_DEPOSIT_AMOUNT, address(this));

        // Bridge to Base
        uint256 susdsSharesBase = IERC4626(Ethereum.SUSDS).convertToShares(SUSDS_BASE_BRIDGE_AMOUNT);
        IERC20(Ethereum.SUSDS).approve(Ethereum.BASE_TOKEN_BRIDGE, susdsSharesBase);
        IOptimismTokenBridge(Ethereum.BASE_TOKEN_BRIDGE).bridgeERC20To(Ethereum.SUSDS, Base.SUSDS, Base.ALM_PROXY, susdsSharesBase, 1_000_000, "");

        // Bridge to Arbitrum
        uint256 susdsSharesArbitrum = susdsShares - susdsSharesBase;
        IERC20(Ethereum.USDS).approve(Ethereum.ARBITRUM_TOKEN_BRIDGE, USDS_ARBITRUM_BRIDGE_AMOUNT);
        IERC20(Ethereum.SUSDS).approve(Ethereum.BASE_TOKEN_BRIDGE, susdsSharesArbitrum);
        // TODO check gas price bid is good
        uint256 gasPrice = 5e9;
        uint256 gasLimit = 1_000_000;
        IArbitrumTokenBridge(Ethereum.ARBITRUM_TOKEN_BRIDGE).outboundTransfer{value:gasLimit*gasPrice}(Ethereum.USDS,  Arbitrum.ALM_PROXY, USDS_ARBITRUM_BRIDGE_AMOUNT, gasLimit, gasLimit, "");
        IArbitrumTokenBridge(Ethereum.ARBITRUM_TOKEN_BRIDGE).outboundTransfer{value:gasLimit*gasPrice}(Ethereum.SUSDS, Arbitrum.ALM_PROXY, susdsSharesArbitrum,                 gasLimit, gasLimit, "");
    }

}
