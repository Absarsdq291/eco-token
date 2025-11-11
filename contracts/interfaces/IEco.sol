// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

/**
 * @title IEco.
 * @author Absar Salahuddin.
 * @notice Interface for the Eco token.
 */
interface IEco {
    /* ========================== EVENTS ========================== */

    /**
     * @notice Emitted when an automated market maker pair is set or unset.
     * @param pair The address of the pair.
     * @param state True if the pair is set as an AMM pair, false otherwise.
     */
    event SetAutomatedMarketMakerPair(address pair, bool state);

    /**
     * @notice Emitted when an account is excluded or included from fees.
     * @param account The address of the account.
     * @param excluded True if the account is excluded from fees, false otherwise.
     */
    event ExcludeFromFees(address account, bool excluded);

    /* ========================== ERRORS ========================== */

    /// @dev Throws when an address is invalid, e.g. `address(0)`.
    error InvalidAddress();

    /// @dev Throws when an assignment is invalid.
    error InvalidAssignment();

    /* ========================== FUNCTIONS ========================== */

    /**
     * @notice Parts per million to serve as a basis point.
     */
    function PPM() external view returns (uint256);

    /**
     * @notice Percentage tax for liquidity, in magnitude of 1e6.
     */
    function LIQUIDITY_TAX() external view returns (uint256);

    /**
     * @notice Percentage tax for marketing, in magnitude of 1e6.
     */
    function MARKETING_TAX() external view returns (uint256);

    /**
     * @notice Percentage tax for development, in magnitude of 1e6.
     */
    function DEVELOPMENT_TAX() external view returns (uint256);

    /**
     * @notice Percentage tax to burn, in magnitude of 1e6.
     */
    function BURN_TAX() external view returns (uint256);

    /**
     * @notice Address of the marketing wallet.
     */
    function marketingWallet() external view returns (address);

    /**
     * @notice Address of the development wallet.
     */
    function developmentWallet() external view returns (address);

    /**
     * @notice Address of the liquidity pool wallet.
     */
    function liquidityPoolWallet() external view returns (address);

    /**
     * @notice Returns whether an address is an automated market maker pair.
     * @param pair The address of the pair.
     * @return state True if the address is an AMM pair, false otherwise.
     */
    function automatedMarketMakerPairs(address pair) external view returns (bool);

    /**
     * @notice Returns whether an account is excluded from fees.
     * @param account The address of the account.
     * @return excluded True if the account is excluded from fees, false otherwise.
     */
    function isExcludedFromFees(address account) external view returns (bool);

    /**
     * @notice Sets or unsets an automated market maker pair.
     * @dev Can only be called by the owner.
     * @param pair The address of the pair.
     * @param state True to set as an AMM pair, false to unset.
     */
    function setAutomatedMarketMakerPair(address pair, bool state) external;

    /**
     * @notice Excludes or includes an account from fees.
     * @dev Can only be called by the owner.
     * @param account The address of the account.
     * @param excluded True to exclude from fees, false to include.
     */
    function excludeFromFees(address account, bool excluded) external;
}
