// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { SpellRunner }                                   from './SpellRunner.sol';
import { ChainIdUtils, ChainId }                         from "src/libraries/ChainId.sol";
import { IMetaMorpho, MarketParams, PendingUint192, Id } from 'lib/metamorpho/src/interfaces/IMetaMorpho.sol';
import { MarketParamsLib }                               from 'lib/metamorpho/lib/morpho-blue/src/libraries/MarketParamsLib.sol';

abstract contract MorphoTests is SpellRunner {
    function _assertMorphoCap(
        MarketParams memory _config,
        uint256             _currentCap,
        bool                _hasPending,
        uint256             _pendingCap
    ) internal {
        Id id                  = MarketParamsLib.id(_config);
        ChainId currentChain   = ChainIdUtils.fromUint(block.chainid);
        IMetaMorpho metaMorpho = IMetaMorpho(chainSpellMetadata[currentChain].morphoVaultDAI);
        require(address(metaMorpho) != address(0), "Morpho/executing on unknown chain");

        assertEq(metaMorpho.config(id).cap, _currentCap);
        PendingUint192 memory pendingCap = metaMorpho.pendingCap(id);
        if (_hasPending) {
            assertEq(pendingCap.value,   _pendingCap);
            assertGt(pendingCap.validAt, 0);
        } else {
            assertEq(pendingCap.value,   0);
            assertEq(pendingCap.validAt, 0);
        }
    }

    function _assertMorphoCap(
        MarketParams memory _config,
        uint256             _currentCap,
        uint256             _pendingCap
    ) internal {
        _assertMorphoCap(_config, _currentCap, true, _pendingCap);
    }

    function _assertMorphoCap(
        MarketParams memory _config,
        uint256             _currentCap
    ) internal {
        _assertMorphoCap(_config, _currentCap, false, 0);
    }
}
