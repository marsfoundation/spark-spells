// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

interface ISparkLendFreezerMom {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     *  @dev   Event to log the freezing of a given market in SparkLend.
     *  @dev   NOTE: This event will fire even if the market is already frozen.
     *  @param reserve The address of the market reserve.
     *  @param freeze  A boolean indicating whether the market is frozen or unfrozen.
     */
    event FreezeMarket(address indexed reserve, bool freeze);

    /**
     *  @dev   Event to log the pausing of a given market in SparkLend.
     *  @dev   NOTE: This event will fire even if the market is already paused.
     *  @param reserve The address of the market reserve.
     *  @param pause   A boolean indicating whether the market is paused or unpaused.
     */
    event PauseMarket(address indexed reserve, bool pause);

    /**
     *  @dev   Event to log the setting of a new owner.
     *  @param oldOwner The address of the previous owner.
     *  @param newOwner The address of the new owner.
     */
    event SetOwner(address indexed oldOwner, address indexed newOwner);

    /**
     *  @dev   Event to log the setting of a new authority.
     *  @param oldAuthority The address of the previous authority.
     *  @param newAuthority The address of the new authority.
     */
    event SetAuthority(address indexed oldAuthority, address indexed newAuthority);

    /**
     *  @dev   Authorize a contract to trigger this mom.
     *  @param usr The address to authorize.
     */
    event Rely(address indexed usr);

    /**
     *  @dev   Deauthorize a contract to trigger this mom.
     *  @param usr The address to deauthorize.
     */
    event Deny(address indexed usr);

    /**********************************************************************************************/
    /*** Storage Variables                                                                      ***/
    /**********************************************************************************************/

    /**
     *  @dev    Returns the address of the pool configurator.
     *  @return The address of the pool configurator.
     */
    function poolConfigurator() external view returns (address);

    /**
     *  @dev    Returns the address of the pool.
     *  @return The address of the pool.
     */
    function pool() external view returns (address);

    /**
     *  @dev    Returns the address of the authority.
     *  @return The address of the authority.
     */
    function authority() external view returns (address);

    /**
     *  @dev    Returns the address of the owner.
     *  @return The address of the owner.
     */
    function owner() external view returns (address);

    /**
     *  @dev    Returns if an address is authorized to trigger this mom (or not).
     *  @return 1 if authorized, 0 if not.
     */
    function wards(address usr) external view returns (uint256);

    /**********************************************************************************************/
    /*** Owner Functions                                                                        ***/
    /**********************************************************************************************/

    /**
     * @dev   Function to set a new authority, permissioned to owner.
     * @param authority The address of the new authority.
     */
    function setAuthority(address authority) external;

    /**
     * @dev   Function to set a new owner, permissioned to owner.
     * @param owner The address of the new owner.
     */
    function setOwner(address owner) external;

    /**
     *  @dev   Authorize a contract to trigger this mom.
     *  @param usr The address to authorize.
     */
    function rely(address usr) external;

    /**
     *  @dev   Deauthorize a contract to trigger this mom.
     *  @param usr The address to deauthorize.
     */
    function deny(address usr) external;

    /**********************************************************************************************/
    /*** Auth Functions                                                                         ***/
    /**********************************************************************************************/

    /**
     *  @dev   Function to freeze a specified market. Permissioned using the isAuthorized function
     *         which allows the owner, a ward, the freezer contract itself, or the `hat` in the
     *         Chief to call the function. Note that the `authority` in this contract is assumed to
     *         be the Chief in the MakerDAO protocol.
     *  @param reserve The address of the market to freeze.
     *  @param freeze  A boolean indicating whether to freeze or unfreeze the market.
     */
    function freezeMarket(address reserve, bool freeze) external;

    /**
     *  @dev   Function to freeze all markets. Permissioned using the isAuthorized function
     *         which allows the owner, a ward, the freezer contract itself, or the `hat` in the
     *         Chief to call the function. Note that the `authority` in this contract is assumed to
     *         be the Chief in the MakerDAO protocol.
     *  @param freeze A boolean indicating whether to freeze or unfreeze the market.
     */
    function freezeAllMarkets(bool freeze) external;

    /**
     *  @dev   Function to pause a specified market. Permissioned using the isAuthorized function
     *         which allows the owner, a ward, the freezer contract itself, or the `hat` in the
     *         Chief to call the function. Note that the `authority` in this contract is assumed to
     *         be the Chief in the MakerDAO protocol.
     *  @param reserve The address of the market to pause.
     *  @param pause   A boolean indicating whether to pause or unpause the market.
     */
    function pauseMarket(address reserve, bool pause) external;

    /**
     *  @dev   Function to pause all markets. Permissioned using the isAuthorized function
     *         which allows the owner, a ward, the freezer contract itself, or the `hat` in the
     *         Chief to call the function. Note that the `authority` in this contract is assumed to
     *         be the Chief in the MakerDAO protocol.
     *  @param pause A boolean indicating whether to pause or unpause the market.
     */
    function pauseAllMarkets(bool pause) external;

}
