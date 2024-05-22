// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';

contract SparkEthereum_20240530Test is SparkEthereumTestBase {

    address public constant GNOSIS_PAYLOAD = address(0);  // TODO

    Domain       mainnet;
    GnosisDomain gnosis;

    constructor() {
        id = '20240530';
    }

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        gnosis  = new GnosisDomain(getChain('gnosis_chain'), mainnet);

        mainnet.rollFork(19918335);  // May 21, 2024
        gnosis.rollFork(34058083);   // May 21, 2024

        mainnet.selectFork();

        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testMorphoSupplyCapUpdates() public {
        MarketParams memory susde1 = MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: Ethereum.SUSDE,
            oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        });
        MarketParams memory susde2 = MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: Ethereum.SUSDE,
            oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        _assertMorphoCap(susde1, 200_000_000e18);
        _assertMorphoCap(susde2, 50_000_000e18);

        GovHelpers.executePayload(vm, payload, executor);

        _assertMorphoCap(susde1, 200_000_000e18, 400_000_000e18);
        _assertMorphoCap(susde2, 50_000_000e18, 100_000_000e18);

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        skip(1 days);

        // These are permissionless (call coming from the test contract)
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(susde1);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(susde2);

        _assertMorphoCap(susde1, 400_000_000e18);
        _assertMorphoCap(susde2, 100_000_000e18);
    }

}
