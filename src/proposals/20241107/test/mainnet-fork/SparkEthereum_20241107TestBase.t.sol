// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';

import { DssSpellAction } from "spells-mainnet/src/DssSpell.sol";

import { ALMProxy }          from 'lib/spark-alm-controller/src/ALMProxy.sol';
import { MainnetController } from 'lib/spark-alm-controller/src/MainnetController.sol';
import { RateLimits }        from 'lib/spark-alm-controller/src/RateLimits.sol';

interface IVatLike {
    function dai(address) external view returns (uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
}

contract SparkEthereum_20241107TestBase is SparkEthereumTestBase {

    constructor() {
        id = '20241107';
    }

    function setUp() public virtual {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 21044602);  // Oct 25, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

}

contract PostSpellExecutionEthereumTestBase is SparkEthereum_20241107TestBase {

    // NOTE: Rate limit rounding errors are 133/hour. So rounding values of 133 and 3200 (133 * 24)
    //       will be used throughout testing.

    bytes32 constant ilk = "ALLOCATOR-SPARK-A";

    address constant freezer = 0x298b375f24CeDb45e936D7e21d6Eb05e344adFb5;  // Gov. facilitator multisig
    address constant relayer = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

    address constant POCKET    = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;
    address constant USDS_JOIN = 0x3C0f895007CA717Aa01c8693e59DF1e8C3777FEB;

    address constant BUFFER   = Ethereum.ALLOCATOR_BUFFER;
    address constant DAI_USDS = Ethereum.DAI_USDS;
    address constant PSM      = Ethereum.PSM;
    address constant VAULT    = Ethereum.ALLOCATOR_VAULT;

    uint256 constant INK                  = 1e12 * 1e18;  // Ink initialization amount
    uint256 constant USDS_MINT_AMOUNT     = 9_000_000e18;
    uint256 constant SUSDS_DEPOSIT_AMOUNT = 8_000_000e18;
    uint256 constant USDS_BRIDGE_AMOUNT   = 1_000_000e18;

    IERC20   constant dai   = IERC20(Ethereum.DAI);
    IERC20   constant usdc  = IERC20(Ethereum.USDC);
    IERC20   constant usds  = IERC20(Ethereum.USDS);
    IERC4626 constant susds = IERC4626(Ethereum.SUSDS);

    IVatLike vat = IVatLike(Ethereum.VAT);

    ALMProxy          constant almProxy          = ALMProxy(payable(Ethereum.ALM_PROXY));
    MainnetController constant mainnetController = MainnetController(Ethereum.ALM_CONTROLLER);
    RateLimits        constant rateLimits        = RateLimits(Ethereum.ALM_RATE_LIMITS);

    /**********************************************************************************************/
    /*** Cached mainnet state variables                                                         ***/
    /**********************************************************************************************/

    uint256 DAI_BAL_PSM;
    uint256 DAI_SUPPLY;
    uint256 USDC_BAL_PSM;
    uint256 USDC_SUPPLY;
    uint256 USDS_SUPPLY;
    uint256 USDS_BAL_SUSDS;
    uint256 VAT_DAI_USDS_JOIN;

    function setUp() public override virtual {
        super.setUp();

        address spell = address(new DssSpellAction());

        vm.etch(Ethereum.PAUSE_PROXY, spell.code);

        DssSpellAction(Ethereum.PAUSE_PROXY).execute();

        executePayload(payload);

        DAI_BAL_PSM       = dai.balanceOf(PSM);
        DAI_SUPPLY        = dai.totalSupply();
        USDC_BAL_PSM      = usdc.balanceOf(POCKET);
        USDC_SUPPLY       = usdc.totalSupply();
        USDS_SUPPLY       = usds.totalSupply();
        USDS_BAL_SUSDS    = usds.balanceOf(address(susds));
        VAT_DAI_USDS_JOIN = vat.dai(USDS_JOIN);
    }

}
