// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IAaveV3ConfigEngine as IEngine } from '../../interfaces/IAaveV3ConfigEngine.sol';
import { IERC20 }                         from 'lib/erc20-helpers/src/interfaces/IERC20.sol';
import { CCTPForwarder }                  from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { Ethereum }          from 'spark-address-registry/Ethereum.sol';

import { SparkLiquidityLayerHelpers }               from "src/libraries/SparkLiquidityLayerHelpers.sol";
import { SparkPayloadEthereum, Rates, EngineFlags } from "../../SparkPayloadEthereum.sol";

/**
 * @title  Jan 23, 2025 Spark Ethereum Proposal
 * @notice Sparklend: Onboard USDS
           Spark Liquidity Layer: Onboard Aave Prime USDS, Sparklend USDS and Sparklend USDC. Update CCTP limits
 * @author Wonderland
 * Forum:  http://forum.sky.money/t/jan-23-2025-proposed-changes-to-spark-for-upcoming-spell/25825
 *         http://forum.sky.money/t/jan-23-2025-proposed-changes-to-spark-for-upcoming-spell-2/25837
 * Vote:   https://vote.makerdao.com/polling/QmRAavx5
 *         https://vote.makerdao.com/polling/QmY4D1u8
 *         https://vote.makerdao.com/polling/QmU3Xu4W
 *         TODO: vote for cctp limits
 */
contract SparkEthereum_20250123 is SparkPayloadEthereum {

    address constant public AAVE_PRIME_USDS_ATOKEN = 0x09AA30b182488f769a9824F15E6Ce58591Da4781;
    address constant public SPARKLEND_USDC_ATOKEN  = 0x377C3bd93f2a2984E1E7bE6A5C22c525eD4A4815;
    // Same oracle composed with chi oracle on 2024-10-17.
    address constant public FIXED_1USD_ORACLE      = 0x42a03F81dd8A1cEcD746dc262e4d1CD9fD39F777;
    address constant public USDS_IRM               = 0x2DB2f1eE78b4e0ad5AaF44969E2E8f563437f34C;

    function newListings() public pure override returns (IEngine.Listing[] memory) {
        IEngine.Listing[] memory listings = new IEngine.Listing[](1);
        listings[0] = IEngine.Listing({
            asset:       Ethereum.USDS,
            assetSymbol: 'USDS',
            priceFeed:   FIXED_1USD_ORACLE,
            // Deploying the default one the listing engine uses out of
            // convenience, will overwrite it in  _postExecute
            rateStrategyParams:                Rates.RateStrategyParams({
                optimalUsageRatio:             0,
                baseVariableBorrowRate:        0,
                variableRateSlope1:            0,
                variableRateSlope2:            0,
                stableRateSlope1:              0,
                stableRateSlope2:              0,
                baseStableRateOffset:          0,
                stableRateExcessOffset:        0,
                optimalStableToTotalDebtRatio: 0
            }), 
            enabledToBorrow:       EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.ENABLED,
            withSiloedBorrowing:   EngineFlags.DISABLED,
            flashloanable:         EngineFlags.DISABLED,
            ltv:                   0,
            liqThreshold:          0,
            liqBonus:              0,
            reserveFactor:         1, // Overriden in _postExecute
            supplyCap:             0,
            borrowCap:             0,
            debtCeiling:           0,
            liqProtocolFee:        10_00, // Overriden in _postExecute
            eModeCategory:         0
        });
        return listings;
    }

    function _postExecute() internal override {
        _onboardAaveToken(
            SPARKLEND_USDC_ATOKEN,
            20_000_000e6,
            uint256(10_000_000e6) / 1 days
        );
        _onboardAaveToken(
            AAVE_PRIME_USDS_ATOKEN,
            50_000_000e18,
            uint256(50_000_000e18) / 1 days
        );

        // Set custom IRM following SSR
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveInterestRateStrategyAddress(
            Ethereum.USDS,
            USDS_IRM
        );
        // Configure USDS market in ways not allowed by the listing engine
        LISTING_ENGINE.POOL_CONFIGURATOR().setReserveFactor(Ethereum.USDS, 0);
        LISTING_ENGINE.POOL_CONFIGURATOR().setLiquidationProtocolFee(Ethereum.USDS, 10_00);

        // Seed the newly listed pool
        IERC20(Ethereum.USDS).approve(address(LISTING_ENGINE.POOL()), 1e18);
        LISTING_ENGINE.POOL().supply(Ethereum.USDS, 1e18, address(this), 0);

        // Set rate limits for the newly listed pool in SLL
        address sparklendUSDSAtoken = LISTING_ENGINE.POOL().getReserveData(Ethereum.USDS).aTokenAddress;
        _onboardAaveToken(
            sparklendUSDSAtoken,
            150_000_000e18,
            uint256(75_000_000e18) / 1 days
        );

        // Amendment rate limits
        SparkLiquidityLayerHelpers.setUSDSMintRateLimit(
            Ethereum.ALM_RATE_LIMITS,
            50_000_000e18,
            uint256(50_000_000e18) / 1 days
        );
        SparkLiquidityLayerHelpers.setUSDSToUSDCRateLimit(
            Ethereum.ALM_RATE_LIMITS,
            50_000_000e6,
            uint256(50_000_000e6) / 1 days
        );
        SparkLiquidityLayerHelpers.setUSDCToDomainRateLimit(
            Ethereum.ALM_RATE_LIMITS,
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            50_000_000e6,
            uint256(25_000_000e6) / 1 days
        );
    }

}
