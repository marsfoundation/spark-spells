// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import { IERC4626 } from 'forge-std/interfaces/IERC4626.sol';
import { IERC20 }   from 'forge-std/interfaces/IERC20.sol';

import { SparkTestBase, ReserveConfig, Ethereum } from 'src/testHarnesses/SparkTestBase.sol';
import { Base }                                   from 'spark-address-registry/Base.sol';
import { Domain, DomainHelpers }                  from "xchain-helpers/testing/Domain.sol";
import { StdChains }                              from "forge-std/StdChains.sol";

import { ForeignController } from 'spark-alm-controller/src/ForeignController.sol';
import { IExecutor }         from 'spark-gov-relay/src/interfaces/IExecutor.sol';

import { IMetaMorpho, MarketParams } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';

import { ChainIdUtils } from 'src/libraries/ChainId.sol';

interface DssAutoLineLike {
    function setIlk(bytes32 ilk, uint256 line, uint256 gap, uint256 ttl) external;
    function exec(bytes32 ilk) external;
}

contract SparkEthereum_20241128Test is SparkTestBase {
    using DomainHelpers         for StdChains.Chain;
    using DomainHelpers         for Domain;

    address internal constant PT_SUSDE_27MAR2025_PRICE_FEED = 0x38d130cEe60CDa080A3b3aC94C79c34B6Fc919A7;
    address internal constant PT_USDE_27MAR2025_PRICE_FEED  = 0xA8ccE51046d760291f77eC1EB98147A75730Dcd5;
    address internal constant PT_SUSDE_27MAR2025            = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81;
    address internal constant PT_USDE_27MAR2025             = 0x8A47b431A7D947c6a3ED6E42d501803615a97EAa;

    address internal constant AUTO_LINE     = 0xC7Bdd1F2B16447dcf3dE045C4a039A60EC2f0ba3;
    bytes32 internal constant ALLOCATOR_ILK = "ALLOCATOR-SPARK-A";

    uint256 internal constant USDS_MINT_AMOUNT = 90_000_000e18;

    constructor() {
        id = '20241128';
    }

    function setUp() public {
        setupDomains({mainnetForkBlock: 21266920, baseForkBlock: 22884550, gnosisForkBlock: 37691338});
        deployPayloads();

        // mock Sky approving 100M liquidity to spark, which will be executed as part of this spell
        vm.prank(Ethereum.PAUSE_PROXY);
        DssAutoLineLike(AUTO_LINE).setIlk(ALLOCATOR_ILK, 100_000_000e45, 100_000_000e45, 24 hours);
        DssAutoLineLike(AUTO_LINE).exec(ALLOCATOR_ILK);
    }

    function testWBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory wbtcConfig         = _findReserveConfigBySymbol(allConfigsBefore, 'WBTC');

        assertEq(wbtcConfig.liquidationThreshold, 65_00);

        executeAllPayloadsAndBridges();

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        wbtcConfig.liquidationThreshold        = 60_00;

        _validateReserveConfig(wbtcConfig, allConfigsAfter);
    }

    function testcbBTCChanges() public {
        ReserveConfig[] memory allConfigsBefore = createConfigurationSnapshot('', pool);
        ReserveConfig memory cbBTCConfig        = _findReserveConfigBySymbol(allConfigsBefore, 'cbBTC');

        assertEq(cbBTCConfig.liquidationThreshold, 70_00);
        assertEq(cbBTCConfig.ltv, 65_00);

        executeAllPayloadsAndBridges();

        ReserveConfig[] memory allConfigsAfter = createConfigurationSnapshot('', pool);
        cbBTCConfig.liquidationThreshold       = 75_00;
        cbBTCConfig.ltv                        = 74_00;

        _validateReserveConfig(cbBTCConfig, allConfigsAfter);
    }

    function testExistingMorphoVault() public {
        MarketParams memory sUSDeVault =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_SUSDE_27MAR2025,
            oracle:          PT_SUSDE_27MAR2025_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        _assertMorphoCap(sUSDeVault, 200_000_000e18);
        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        executeAllPayloadsAndBridges();

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);
        _assertMorphoCap(sUSDeVault, 200_000_000e18, 400_000_000e18);

        skip(1 days);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(sUSDeVault);
        _assertMorphoCap(sUSDeVault, 400_000_000e18);
    }

    function testNewMorphoVault() public {
        MarketParams memory USDeVault =  MarketParams({
            loanToken:       Ethereum.DAI,
            collateralToken: PT_USDE_27MAR2025,
            oracle:          PT_USDE_27MAR2025_PRICE_FEED,
            irm:             Ethereum.MORPHO_DEFAULT_IRM,
            lltv:            0.915e18
        });

        _assertMorphoCap(USDeVault, 0);
        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);

        executeAllPayloadsAndBridges();

        assertEq(IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).timelock(), 1 days);
        _assertMorphoCap(USDeVault, 0, 100_000_000e18);

        skip(1 days);
        IMetaMorpho(Ethereum.MORPHO_VAULT_DAI_1).acceptCap(USDeVault);
        _assertMorphoCap(USDeVault, 100_000_000e18);
    }

    function testBridging() external {
        uint256 baseBalanceBefore = 123496652107156694;
        uint256 SUSDSShares       = IERC4626(Ethereum.SUSDS).convertToShares(USDS_MINT_AMOUNT);

        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), baseBalanceBefore);

        executeAllPayloadsAndBridges();

        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), baseBalanceBefore + SUSDSShares);
    }

    function testE2ELiquidityProvisioningToBase() external {
        ForeignController controller = ForeignController(Base.ALM_CONTROLLER);
        address relayer              = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

        uint256 baseALMBalanceBefore = 123496652107156694;
        uint256 basePSMBalanceBefore = 7561335102296991391227534;
        uint256 SUSDSShares          = IERC4626(Ethereum.SUSDS).convertToShares(USDS_MINT_AMOUNT);
        uint256 depositAmount        = 1_000_000e18;

        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.PSM3), basePSMBalanceBefore);

        // insufficient ALM_PROXY balance prevents the deposit
        vm.prank(relayer);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        controller.depositPSM(Base.SUSDS, depositAmount);

        chainSpellMetadata[ChainIdUtils.Ethereum()].domain.selectFork();

        executeAllPayloadsAndBridges();
        
        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        assertEq(IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY), baseALMBalanceBefore + SUSDSShares);
        // after funds are bridged, liquidity can be provisioned to the PSM
        vm.prank(relayer);
        controller.depositPSM(Base.SUSDS, depositAmount);
        assertEq(
          IERC20(Base.SUSDS).balanceOf(Base.PSM3),
          basePSMBalanceBefore + depositAmount
        );
        assertEq(
          IERC20(Base.SUSDS).balanceOf(Base.ALM_PROXY),
          baseALMBalanceBefore + SUSDSShares - depositAmount
        );
    }

    function testBasePayloadExecution() external {
        chainSpellMetadata[ChainIdUtils.Base()].domain.selectFork();
        IExecutor executor = IExecutor(Base.SPARK_EXECUTOR);
        assertEq(IExecutor(Base.SPARK_EXECUTOR).actionsSetCount(), 1);
        assertEq(executor.delay(),       100);
        assertEq(executor.gracePeriod(), 1000);

        executeAllPayloadsAndBridges();

        assertEq(IExecutor(Base.SPARK_EXECUTOR).actionsSetCount(), 2);
        skip(100 seconds);
        IExecutor(Base.SPARK_EXECUTOR).execute(1);
        assertEq(executor.delay(),       0);
        assertEq(executor.gracePeriod(), 7 days);
    }
}
