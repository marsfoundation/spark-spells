// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0;

import { IPool }             from "sparklend-v1-core/contracts/interfaces/IPool.sol";
import { IPoolConfigurator } from "sparklend-v1-core/contracts/interfaces/IPoolConfigurator.sol";

interface IKillSwitchOracle {

    /******************************************************************************************************************/
    /*** Events                                                                                                     ***/
    /******************************************************************************************************************/

    /** 
     *  @dev  Emitted when the oracle is set or updated.
     *  @param oracle    The address of the oracle being set or updated.
     *  @param threshold The oracle price threshold to trigger the kill switch.
     */
    event SetOracle(address indexed oracle, uint256 threshold);

    /** 
     * @dev   Emitted when an oracle is disabled.
     * @param oracle The address of the oracle being disabled.
     */
    event DisableOracle(address indexed oracle);

    /**
     *  @dev   Emitted when the kill switch is triggered by the oracle below its threshold.
     *  @param oracle    The address of the oracle that met the trigger condition.
     *  @param threshold The threshold value that was compared against the price.
     *  @param price     The price that met or exceeded the threshold value.
     */
    event Trigger(address indexed oracle, uint256 threshold, uint256 price);

    /**
     *  @dev   Emitted when the borrow is disabled for an asset.
     *  @param asset The address of the asset whose borrow has been disabled.
     */
    event BorrowDisabled(address indexed asset);

    /**
     *  @dev Emitted when the contract is reset.
     */
    event Reset();

    /******************************************************************************************************************/
    /*** Storage Variables                                                                                          ***/
    /******************************************************************************************************************/

    /**
     *  @dev    Returns the address of the pool configurator.
     *  @return poolConfigurator The address of the pool configurator.
     */
    function poolConfigurator() external view returns (IPoolConfigurator poolConfigurator);

    /**
     *  @dev    Returns the address of the data provider.
     *  @return pool The address of the data provider.
     */
    function pool() external view returns (IPool pool);

    /**
     *  @dev    Returns true if the kill switch has been triggered.
     *  @return _triggered A boolean indicating whether the kill switch has been triggered.
     */
    function triggered() external view returns (bool _triggered);

    /**
     * @dev    Returns the threshold for the provided oracle.
     * @param  oracle The address of the oracle.
     * @return threshold The threshold for the provided oracle.
     */
    function oracleThresholds(address oracle) external view returns (uint256 threshold);

    /******************************************************************************************************************/
    /*** Owner Functions                                                                                            ***/
    /******************************************************************************************************************/

    /**
     * @dev   Sets or updates the oracle with a new threshold value.
     * @param oracle    The address of the oracle to set or update.
     * @param threshold The new threshold value to associate with the oracle.
     */
    function setOracle(address oracle, uint256 threshold) external;

    /**
     * @dev   Disables a specified oracle, preventing it from being used.
     * @param oracle The address of the oracle to disable.
     */
    function disableOracle(address oracle) external;

    /**
     * @dev Reset the module so that the kill switch can only be triggered if one of
     *      the oracles is below the threshold.
     */
    function reset() external;


    /******************************************************************************************************************/
    /*** Getter Functions                                                                                           ***/
    /******************************************************************************************************************/

    /**
     * @dev    Returns the total number of oracles being monitored.
     * @return _numOracles The total number of oracles.
     */
    function numOracles() external view returns (uint256 _numOracles);

    /**
     * @dev    Returns the address of the oracle at a given index.
     * @param  index  The index of the oracle in the storage array.
     * @return oracle The address of the oracle at the specified index.
     */
    function oracleAt(uint256 index) external view returns (address oracle);

    /**
     * @dev    Checks if a given address is an oracle being monitored.
     * @param  oracle     The address to check.
     * @return _hasOracle True if the address is an oracle being monitored.
     */
    function hasOracle(address oracle) external view returns (bool _hasOracle);

    /**
     * @dev    Returns an array containing the addresses of all oracles being monitored.
     * @return _oracles An array of oracle addresses.
     */
    function oracles() external view returns (address[] memory _oracles);

    /******************************************************************************************************************/
    /*** Public Functions                                                                                           ***/
    /******************************************************************************************************************/

    /**
     * @notice Permissionless function to trigger the kill switch.
     * @dev    If the kill switch has not been triggered, the oracle threshold has been defined,
     *         and the oracle is below the threshold, the kill switch is triggered. This will
     *         disable borrowing on all assets. If the kill switch has been triggered, this
     *         function will allow disabling borrowing on all assets until the kill switch is reset.
     * @param  oracle The address of the oracle which is below the threshold. If the kill switch
     *                has been triggered, this parameter is ignored.
     */
    function trigger(address oracle) external;

}
