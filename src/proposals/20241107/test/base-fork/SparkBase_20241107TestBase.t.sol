// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import 'src/SparkTestBase.sol';

import { ALMProxy }          from 'lib/spark-alm-controller/src/ALMProxy.sol';
import { ForeignController } from 'lib/spark-alm-controller/src/ForeignController.sol';
import { RateLimits }        from 'lib/spark-alm-controller/src/RateLimits.sol';

import { IPSM3 } from "lib/spark-psm/src/interfaces/IPSM3.sol";

contract SparkBase_20241107TestBase is SparkBaseTestBase {

    constructor() {
        id = '20241107';
    }

    function setUp() public virtual {
        vm.createSelectFork(getChain('base').rpcUrl, 21676960);  // Oct 28, 2024
        payload = deployPayload();
    }

}

contract PostSpellExecutionBaseTestBase is SparkBase_20241107TestBase {

    address constant SPARK_EXECUTOR = Base.SPARK_EXECUTOR;

    address constant freezer = address(0);  // TODO Gov. facilitator multisig
    address constant relayer = 0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB;

    IERC20 constant usdcBase  = IERC20(Base.USDC);
    IERC20 constant usdsBase  = IERC20(Base.USDS);
    IERC20 constant susdsBase = IERC20(Base.SUSDS);

    IPSM3 constant psmBase = IPSM3(Base.PSM3);

    address constant pocket = Base.PSM3;  // Pocket is PSM in initial configuration

    ALMProxy          constant almProxy          = ALMProxy(payable(Base.ALM_PROXY));
    ForeignController constant foreignController = ForeignController(Base.ALM_CONTROLLER);
    RateLimits        constant rateLimits        = RateLimits(Base.ALM_RATE_LIMITS);

    function setUp() public override virtual {
        super.setUp();
        executePayload(payload);
    }

}
