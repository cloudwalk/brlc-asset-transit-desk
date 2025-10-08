// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IAssetTransitDeskPrimary {
    // ------------------ Events ---------------------------------- //

    event AssetIssued(address buyer, uint64 principalAmount);
    event AssetRedeemed(address buyer, uint64 principalAmount, uint64 netYieldAmount);

    // ------------------ Transactional functions ----------------- //

    /**
     * @dev Issues an asset.
     *
     * Emits an {AssetIssued} event.
     *
     * @param buyer The address of the buyer.
     * @param principalAmount The amount of the principal.
     */
    function issueAsset(address buyer, uint64 principalAmount) external;

    /**
     * @dev Redeems an asset.
     *
     * Emits an {AssetRedeemed} event.
     *
     * @param buyer The address of the buyer.
     * @param principalAmount The amount of the principal.
     * @param netYieldAmount The amount of the net yield.
     */
    function redeemAsset(address buyer, uint64 principalAmount, uint64 netYieldAmount) external;
}

/**
 * @title IAssetTransitDeskConfiguration interface
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev The configuration part of the asset desk smart contract interface.
 */
interface IAssetTransitDeskConfiguration {
    // ------------------ Events ---------------------------------- //

    event SurplusTreasuryChanged(address newSurplusTreasury, address oldSurplusTreasury);
    event LPTreasuryChanged(address newLPTreasury, address oldLPTreasury);

    // ------------------ Transactional functions ----------------- //

    /**
     * @dev Sets the surplus treasury address.
     *
     * Emits an {SurplusTreasuryChanged} event.
     *
     * @param newSurplusTreasury The new address of the surplus treasury to set.
     */
    function setSurplusTreasury(address newSurplusTreasury) external;

    /**
     * @dev Sets the LP treasury address.
     *
     * Emits an {LPTreasuryChanged} event.
     *
     * @param newLPTreasury The new address of the LP treasury to set.
     */
    function setLPTreasury(address newLPTreasury) external;

    // ------------------ View functions -------------------------- //

    /**
     * @dev Returns the address of the surplus treasury.
     *
     * @return The address of the surplus treasury.
     */
    function getSurplusTreasury() external view returns (address);

    /**
     * @dev Returns the address of the LP treasury.
     *
     * @return The address of the LP treasury.
     */
    function getLPTreasury() external view returns (address);

    /**
     * @dev Returns the address of the underlying token.
     *
     * @return The address of the underlying token.
     */
    function underlyingToken() external view returns (address);
}

/**
 * @title IAssetTransitDeskErrors interface
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev Defines the custom errors used in the asset desk contract.
 *
 * The errors are ordered alphabetically.
 */
interface IAssetTransitDeskErrors {
    /// @dev Thrown if the provided buyer address is zero.
    error AssetTransitDesk_BuyerAddressZero();

    /// @dev Thrown if the provided new implementation address is not of a asset desk contract.
    error AssetTransitDesk_ImplementationAddressInvalid();

    /// @dev Thrown if the provided net yield amount is zero.
    error AssetTransitDesk_NetYieldAmountZero();

    /// @dev Thrown if the provided principal amount is zero.
    error AssetTransitDesk_PrincipalAmountZero();

    /// @dev Thrown if the provided token address is zero.
    error AssetTransitDesk_TokenAddressZero();

    /// @dev Thrown if the provided treasury has not granted the contract allowance to spend tokens.
    error AssetTransitDesk_TreasuryAllowanceZero();

    /// @dev Thrown if the provided treasury address is already configured.
    error AssetTransitDesk_TreasuryAlreadyConfigured();

    /// @dev Thrown if the provided treasury address is zero.
    error AssetTransitDesk_TreasuryZero();
}

/**
 * @title IAssetTransitDesk interface
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev The full interface of the asset desk smart contract.
 *
 * The smart contract to manage and log token transfers related to some CDB buying and selling operations.
 */
interface IAssetTransitDesk is IAssetTransitDeskPrimary, IAssetTransitDeskConfiguration, IAssetTransitDeskErrors {
    /**
     * @dev Proves the contract is the asset desk one. A marker function.
     *
     * It is used for simple contract compliance checks, e.g. during an upgrade.
     * This avoids situations where a wrong contract address is specified by mistake.
     */
    function proveAssetTransitDesk() external pure;
}
