// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

contract SparkEthereum_20240725Test is SparkEthereumTestBase {

    address public constant PT_SUSDE_24OCT2024 = 0xAE5099C39f023C91d3dd55244CAFB36225B0850E;

    constructor() {
        id = '20240725';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20336135);
        payload = 0xc585A1AF765D392D8267a710b811ab41CbD989a3;

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function testSpellSpecifics() public {
        MarketParams memory ptsusde = MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_24OCT2024,
            oracle:          Ethereum.MORPHO_SUSDE_ORACLE,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.86e18
        });

        _assertMorphoCap(ptsusde, 0);

        executePayload(payload);

        _assertMorphoCap(ptsusde, 0, 100_000_000e18);

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        skip(1 days);

        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(ptsusde);

        _assertMorphoCap(ptsusde, 100_000_000e18);
    }

}
