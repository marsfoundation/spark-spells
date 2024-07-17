// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import '../../SparkTestBase.sol';

import { IL2BridgeExecutor } from 'spark-gov-relay/interfaces/IL2BridgeExecutor.sol';

import { Domain, GnosisDomain } from 'xchain-helpers/testing/GnosisDomain.sol';

import { SparkGnosis_20240627 } from './SparkGnosis_20240627.sol';

contract SparkEthereum_20240627Test is SparkEthereumTestBase {

    address public constant USDCE = 0x2a22f9c3b484c3629090FeED35F17Ff8F88f76F0;

    Domain       mainnet;
    GnosisDomain gnosis;

    constructor() {
        id = '20240627';
    }

    function setUp() public {
        mainnet = new Domain(getChain('mainnet'));
        gnosis  = new GnosisDomain(getChain('gnosis_chain'), mainnet);

        mainnet.rollFork(20134486);  // June 20, 2024
        gnosis.rollFork(34563897);   // June 20, 2024

        payload = 0xc96420Dbe9568e2a65DD57daAD069FDEd37265fa;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testGnosisSpellExecution() public {
        executePayload(payload);

        gnosis.selectFork();

        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getActionsSetCount(), 5);

        gnosis.relayFromHost(true);
        skip(2 days);

        assertEq(IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).getActionsSetCount(), 6);

        assertEq(createConfigurationSnapshot('', IPool(Gnosis.POOL)).length, 8);

        IL2BridgeExecutor(Gnosis.AMB_EXECUTOR).execute(5);

        assertEq(createConfigurationSnapshot('', IPool(Gnosis.POOL)).length, 9);
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

        _assertMorphoCap(susde1, 400_000_000e18);
        _assertMorphoCap(susde2, 100_000_000e18);

        executePayload(payload);

        _assertMorphoCap(susde1, 400_000_000e18, 500_000_000e18);
        _assertMorphoCap(susde2, 100_000_000e18, 200_000_000e18);

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        skip(1 days);

        // These are permissionless (call coming from the test contract)
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(susde1);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(susde2);

        _assertMorphoCap(susde1, 500_000_000e18);
        _assertMorphoCap(susde2, 200_000_000e18);
    }

}
