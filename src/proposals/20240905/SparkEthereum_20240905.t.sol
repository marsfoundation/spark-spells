// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { IKillSwitchOracle } from 'lib/sparklend-kill-switch/src/interfaces/IKillSwitchOracle.sol';

interface IPriceSource {
    function decimals() external view returns (uint8 decimals);
    function latestAnswer() external view returns (int256 price);
}

interface ILSTOracle {
    function ethSource() external view returns (IPriceSource priceSource);
    function latestAnswer() external view returns (uint256 price);
}

interface IAggor {
    function ageThreshold() external view returns (uint32 ageThreshold);
    function agreementDistance() external view returns (uint128 agreementDistance);
    function authed() external view returns (address[] memory authedAddresses);
    function chainlink() external view returns (address chainlink);
    function chronicle() external view returns (address chronicle);
    function decimals() external view returns (uint8 decimals);
    function tolled() external view returns (address[] memory tolledAddresses);
    function uniswapBaseToken() external view returns (address baseToken);
    function uniswapBaseTokenDecimals() external view returns (uint8 baseTokenDecimals);
    function uniswapLookback() external view returns (uint32 lookback);
    function uniswapPool() external view returns (address pool);
    function uniswapQuoteToken() external view returns (address quoteToken);
    function uniswapQuoteTokenDecimals() external view returns (uint8 quoteTokenDecimals);
}

contract SparkEthereum_20240905Test is SparkEthereumTestBase {

    address internal constant AGGOR_RETH   = 0x69115a2826Eb47FE9DFD1d5CA8D8642697c8b68A;
    address internal constant AGGOR_WEETH  = 0xb20A1374EfCaFa32F701Ab14316fA2E5b3400eD5;
    address internal constant AGGOR_WSTETH = 0x00480CD3ed33de45555410BA71b2F932A14b1Cf2;

    address internal constant RETH_ORACLE_OLD   = 0x05225Cd708bCa9253789C1374e4337a019e99D56;
    address internal constant WEETH_ORACLE_OLD  = 0x1A6BDB22b9d7a454D20EAf12DB55D6B5F058183D;
    address internal constant WETH_ORACLE_OLD   = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal constant WSTETH_ORACLE_OLD = 0x8B6851156023f4f5A66F68BEA80851c3D905Ac93;

    address internal constant RETH_ORACLE   = 0x11af58f13419fD3ce4d3A90372200c80Bc62f140;
    address internal constant WEETH_ORACLE  = 0x28897036f8459bFBa886083dD6b4Ce4d2f14a57F;
    address internal constant WETH_ORACLE   = 0xf07ca0e66A798547E4CB3899EC592e1E99Ef6Cb3;
    address internal constant WSTETH_ORACLE = 0xf77e132799DBB0d83A4fB7df10DA04849340311A;

    address internal constant WBTC_BTC_ORACLE = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;

    address internal constant CHRONICLE_ETH_USD_3    = 0x46ef0071b1E2fF6B42d36e5A177EA43Ae5917f4E;
    address internal constant UNISWAP_WETH_USDC_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    constructor() {
        id = '20240905';
    }

    function setUp() public {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20613541);  // Aug 26, 2024
        payload = deployPayload();

        loadPoolContext(poolAddressesProviderRegistry.getAddressesProvidersList()[0]);
    }

    function test_validateOracles() public {
        vm.startPrank(Ethereum.AAVE_ORACLE);
        uint256 oldRETHPrice = uint256(IPriceSource(RETH_ORACLE_OLD).latestAnswer());
        uint256 newRETHPrice = uint256(IPriceSource(RETH_ORACLE).latestAnswer());

        uint256 oldWEETHPrice = uint256(IPriceSource(WEETH_ORACLE_OLD).latestAnswer());
        uint256 newWEETHPrice = uint256(IPriceSource(WEETH_ORACLE).latestAnswer());

        uint256 oldWETHPrice = uint256(IPriceSource(WETH_ORACLE_OLD).latestAnswer());
        uint256 newWETHPrice = uint256(IPriceSource(WETH_ORACLE).latestAnswer());

        uint256 oldWSTETHPrice = uint256(IPriceSource(WSTETH_ORACLE_OLD).latestAnswer());
        uint256 newWSTETHPrice = uint256(IPriceSource(WSTETH_ORACLE).latestAnswer());
        vm.stopPrank();

        // Less than 1% difference between the old and new oracles
        assertApproxEqRel(oldRETHPrice,   newRETHPrice,   0.01e18);
        assertApproxEqRel(oldWEETHPrice,  newWEETHPrice,  0.01e18);
        assertApproxEqRel(oldWETHPrice,   newWETHPrice,   0.01e18);
        assertApproxEqRel(oldWSTETHPrice, newWSTETHPrice, 0.01e18);

        // Assert LST oracles
        assertEq(newRETHPrice,   3032.01088588e8);
        assertEq(newWEETHPrice,  2846.68804265e8);
        assertEq(newWSTETHPrice, 3201.79875087e8);

        uint256 ethPrice = 2720.27775835e8;

        // Assert all aggor oracles 
        vm.prank(Ethereum.AAVE_ORACLE);
        assertEq(uint256(IPriceSource(WETH_ORACLE).latestAnswer()), ethPrice);
        
        vm.prank(RETH_ORACLE);
        assertEq(uint256(IPriceSource(AGGOR_RETH).latestAnswer()), ethPrice);
        assertEq(address(ILSTOracle(RETH_ORACLE).ethSource()),     AGGOR_RETH);

        vm.prank(WEETH_ORACLE);
        assertEq(uint256(IPriceSource(AGGOR_WEETH).latestAnswer()), ethPrice);
        assertEq(address(ILSTOracle(WEETH_ORACLE).ethSource()),     AGGOR_WEETH);

        vm.prank(WSTETH_ORACLE);
        assertEq(uint256(IPriceSource(AGGOR_WSTETH).latestAnswer()), ethPrice);
        assertEq(address(ILSTOracle(WSTETH_ORACLE).ethSource()),     AGGOR_WSTETH);

        // Before execution, aave oracle prices match the old oracles
        IAaveOracle oracle = IAaveOracle(Ethereum.AAVE_ORACLE);
        assertEq(oracle.getAssetPrice(Ethereum.RETH),   oldRETHPrice);
        assertEq(oracle.getAssetPrice(Ethereum.WETH),   oldWETHPrice);
        assertEq(oracle.getAssetPrice(Ethereum.WEETH),  oldWEETHPrice);
        assertEq(oracle.getAssetPrice(Ethereum.WSTETH), oldWSTETHPrice);

        executePayload(payload);

        // After execution, aave oracle prices match the new oracles
        assertEq(oracle.getAssetPrice(Ethereum.RETH),   newRETHPrice);
        assertEq(oracle.getAssetPrice(Ethereum.WETH),   newWETHPrice);
        assertEq(oracle.getAssetPrice(Ethereum.WEETH),  newWEETHPrice);
        assertEq(oracle.getAssetPrice(Ethereum.WSTETH), newWSTETHPrice);
    }

    function test_validateAggorOracles() public {
        address[] memory tolledAddresses = new address[](4);
        tolledAddresses[0] = RETH_ORACLE;
        tolledAddresses[1] = WEETH_ORACLE;
        tolledAddresses[2] = WSTETH_ORACLE;
        tolledAddresses[3] = Ethereum.AAVE_ORACLE;

        IAggor[] memory aggorOracles = new IAggor[](4);
        aggorOracles[0] = IAggor(AGGOR_RETH);
        aggorOracles[1] = IAggor(AGGOR_WEETH);
        aggorOracles[2] = IAggor(AGGOR_WSTETH);
        aggorOracles[3] = IAggor(WETH_ORACLE);

        for(uint256 i; i < aggorOracles.length; i++) {
            IAggor oracle = aggorOracles[i];
            assertEq(oracle.ageThreshold(),              25 hours);
            assertEq(oracle.agreementDistance(),         0.02e18);
            assertEq(oracle.chainlink(),                 WETH_ORACLE_OLD);
            assertEq(oracle.chronicle(),                 CHRONICLE_ETH_USD_3);
            assertEq(oracle.decimals(),                  8);
            assertEq(oracle.uniswapPool(),               UNISWAP_WETH_USDC_POOL);
            assertEq(oracle.uniswapBaseToken(),          Ethereum.WETH);
            assertEq(oracle.uniswapQuoteToken(),         Ethereum.USDC);
            assertEq(oracle.uniswapBaseTokenDecimals(),  18);
            assertEq(oracle.uniswapQuoteTokenDecimals(), 6);
            assertEq(oracle.uniswapLookback(),           1 hours);
            
            address[] memory authed = oracle.authed();
            assertEq(authed.length, 1);
            assertEq(authed[0],     Ethereum.SPARK_PROXY);

            address[] memory tolled = oracle.tolled();
            assertEq(tolled.length, 2);
            assertEq(tolled[0],     address(0));
            assertEq(tolled[1],     tolledAddresses[i]);
        }
    }

    function test_marketConfigChanges() public {
        // Manually test the old RETH oracle as it does not have the decimals method
        IAaveOracle oracle = IAaveOracle(poolAddressesProvider.getPriceOracle());
        require(oracle.getSourceOfAsset(Ethereum.RETH) == RETH_ORACLE_OLD, 
            '_validateAssetSourceOnOracle() : INVALID_PRICE_SOURCE'
        );

        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WEETH,  WEETH_ORACLE_OLD);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WETH,   WETH_ORACLE_OLD);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WSTETH, WSTETH_ORACLE_OLD);

        executePayload(payload);

        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.RETH,   RETH_ORACLE);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WEETH,  WEETH_ORACLE);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WETH,   WETH_ORACLE);
        _validateAssetSourceOnOracle(poolAddressesProvider, Ethereum.WSTETH, WSTETH_ORACLE);
    }

    function test_disableKillSwitchOracle() public {
        IKillSwitchOracle killSwitchOracle = IKillSwitchOracle(Ethereum.KILL_SWITCH_ORACLE);

        assertEq(killSwitchOracle.hasOracle(WBTC_BTC_ORACLE), true);
        
        executePayload(payload);
        
        // Has oracle is now false
        assertEq(killSwitchOracle.hasOracle(WBTC_BTC_ORACLE), false);

        // Reverts when calling trigger
        vm.expectRevert("KillSwitchOracle/oracle-does-not-exist");
        killSwitchOracle.trigger(WBTC_BTC_ORACLE);
    }

}
