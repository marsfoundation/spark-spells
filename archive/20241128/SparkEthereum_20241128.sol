// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IERC20 }   from 'forge-std/interfaces/IERC20.sol';
import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { Ethereum, SparkPayloadEthereum, IEngine, EngineFlags } from 'src/SparkPayloadEthereum.sol';
import { Base }                                                 from 'spark-address-registry/Base.sol';

import { IMetaMorpho, MarketParams } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';

import { AllocatorBuffer } from 'dss-allocator/src/AllocatorBuffer.sol';
import { AllocatorVault }  from 'dss-allocator/src/AllocatorVault.sol';

import { OptimismForwarder } from 'xchain-helpers/forwarders/OptimismForwarder.sol';

interface ITokenBridge {
    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

/**
 * @title  Nov 28, 2024 Spark Ethereum Proposal
 * @notice Sparklend: update WBTC and cbBTC parameters
           Spark ALM: Provision 90M worth of SUSDS to the Base ALM Proxy
 *         Morpho: onboard PT-USDe-27Mar2025 and increase PT-sUSDe-27Mar2025 cap
 * @author Wonderland
 * Forum:  https://forum.sky.money/t/28-nov-2024-proposed-changes-to-spark-for-upcoming-spell/25543/2
 *         https://forum.sky.money/t/28-nov-2024-proposed-changes-to-spark-for-upcoming-spell-amendments/25575
 * Vote:   https://vote.makerdao.com/polling/QmSxJJ6Z (WBTC changes)
 *         https://vote.makerdao.com/polling/QmaxFZfF (cbBTC changes)
 *         https://vote.makerdao.com/polling/QmWUkstV (Morpho listing)
 *         https://vote.makerdao.com/polling/QmcNd4mH (Provision liquidity to Base ALM Proxy)
 */
contract SparkEthereum_20241128 is SparkPayloadEthereum {

    address internal constant PT_SUSDE_27MAR2025_PRICE_FEED = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address internal constant PT_USDE_27MAR2025_PRICE_FEED  = 0xA8ccE51046d760291f77eC1EB98147A75730Dcd5;
    address internal constant PT_SUSDE_27MAR2025            = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;
    address internal constant PT_USDE_27MAR2025             = 0x8A47b431A7D947c6a3ED6E42d501803615a97EAa;

    uint256 internal constant USDS_MINT_AMOUNT = 90_000_000e18;
    address internal constant BASE_PAYLOAD     = 0x7C4b5f3Aeb694db68682D6CE5521702170e61E45;

    function collateralsUpdates() public pure override returns (IEngine.CollateralUpdate[] memory) {
        IEngine.CollateralUpdate[] memory updates = new IEngine.CollateralUpdate[](2);

        // Reduce LT from 65% to 60%
        updates[0] = IEngine.CollateralUpdate({
            asset:          Ethereum.WBTC,
            ltv:            EngineFlags.KEEP_CURRENT,
            liqThreshold:   60_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        // Increase LT from 70% to 75%
        // Increase LTV from 65% to 74%
        updates[1] = IEngine.CollateralUpdate({
            asset:          Ethereum.CBBTC,
            ltv:            74_00,
            liqThreshold:   75_00,
            liqBonus:       EngineFlags.KEEP_CURRENT,
            debtCeiling:    EngineFlags.KEEP_CURRENT,
            liqProtocolFee: EngineFlags.KEEP_CURRENT,
            eModeCategory:  EngineFlags.KEEP_CURRENT
        });

        return updates;
    }

    function _postExecute() internal override {
        // update existing cap for PT-sUSDe-27Mar2025 200m -> 400m
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_SUSDE_27MAR2025,
                oracle:          PT_SUSDE_27MAR2025_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            400_000_000e18
        );

        // set cap for new market
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).submitCap(
            MarketParams({
                loanToken:       Ethereum.DAI,
                collateralToken: PT_USDE_27MAR2025,
                oracle:          PT_USDE_27MAR2025_PRICE_FEED,
                irm:             Ethereum.MORPHO_DEFAULT_IRM,
                lltv:            0.915e18
            }),
            100_000_000e18
        );

        // mint 90M USDS
        AllocatorVault(Ethereum.ALLOCATOR_VAULT).draw(USDS_MINT_AMOUNT);
        AllocatorBuffer(Ethereum.ALLOCATOR_BUFFER).approve(Ethereum.USDS, address(this), USDS_MINT_AMOUNT);
        IERC20(Ethereum.USDS).transferFrom(Ethereum.ALLOCATOR_BUFFER, address(this), USDS_MINT_AMOUNT);

        // convert them all into SUSDS
        IERC20(Ethereum.USDS).approve(Ethereum.SUSDS, USDS_MINT_AMOUNT);
        uint256 susdsShares = IERC4626(Ethereum.SUSDS).deposit(USDS_MINT_AMOUNT, address(this));

        // bridge them to Base
        IERC20(Ethereum.SUSDS).approve(Ethereum.BASE_TOKEN_BRIDGE, susdsShares);
        ITokenBridge(Ethereum.BASE_TOKEN_BRIDGE).bridgeERC20To(Ethereum.SUSDS, Base.SUSDS, Base.ALM_PROXY, susdsShares, 1_000_000, "");

        // Trigger Base payload 
        OptimismForwarder.sendMessageL1toL2({
            l1CrossDomain: OptimismForwarder.L1_CROSS_DOMAIN_BASE,
            target:        Base.SPARK_RECEIVER,
            message:       encodePayloadQueue(BASE_PAYLOAD),
            gasLimit:      1_000_000
        });
    }
}
