// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IAssetDeskPrimary {
    // ------------------ Events ---------------------------------- //

    event AssetIssued(address buyer, uint64 principalAmount);
    event AssetRedeemed(address buyer, uint64 principalAmount, uint64 netYieldAmount, uint64 taxAmount);

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
     * @param taxAmount The amount of the tax.
     */
    function redeemAsset(address buyer, uint64 principalAmount, uint64 netYieldAmount, uint64 taxAmount) external;
}

/**
 * @title IAssetDeskConfiguration interface
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev The configuration part of the asset desk smart contract interface.
 */
interface IAssetDeskConfiguration {
    // ------------------ Events ---------------------------------- //

    event SurplusTreasuryChanged(address newSurplusTreasury, address oldSurplusTreasury);
    event LPTreasuryChanged(address newLPTreasury, address oldLPTreasury);
    event TaxTreasuryChanged(address newTaxTreasury, address oldTaxTreasury);

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

    /**
     * @dev Sets the tax treasury address.
     *
     * Emits an {TaxTreasuryChanged} event.
     *
     * @param newTaxTreasury The new address of the tax treasury to set.
     */
    function setTaxTreasury(address newTaxTreasury) external;

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
     * @dev Returns the address of the tax treasury.
     *
     * @return The address of the tax treasury.
     */
    function getTaxTreasury() external view returns (address);

    /**
     * @dev Returns the address of the underlying token.
     *
     * @return The address of the underlying token.
     */
    function underlyingToken() external view returns (address);
}

/**
 * @title IAssetDeskErrors interface
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev Defines the custom errors used in the asset desk contract.
 *
 * The errors are ordered alphabetically.
 */
interface IAssetDeskErrors {
    /// @dev Thrown if the provided buyer address is zero.
    error AssetDesk_BuyerAddressZero();

    /// @dev Thrown if the provided new implementation address is not of a asset desk contract.
    error AssetDesk_ImplementationAddressInvalid();

    /// @dev Thrown if the provided net yield amount is zero.
    error AssetDesk_NetYieldAmountZero();

    /// @dev Thrown if the provided principal amount is zero.
    error AssetDesk_PrincipalAmountZero();

    /// @dev Thrown if the provided token address is zero.
    error AssetDesk_TokenAddressZero();

    /// @dev Thrown if the provided treasury has not granted the contract allowance to spend tokens.
    error AssetDesk_TreasuryAllowanceZero();

    /// @dev Thrown if the provided treasury address is already configured.
    error AssetDesk_TreasuryAlreadyConfigured();

    /// @dev Thrown if the provided treasury address is zero.
    error AssetDesk_TreasuryZero();

    /// @dev Thrown if the provided tax amount is zero.
    error AssetDesk_TaxAmountZero();
}

/**
 * @title IAssetDesk interface
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev The full interface of the asset desk smart contract.
 *
 * The smart contract to manage and log token transfers related to some CDB buying and selling operations.
 */
interface IAssetDesk is IAssetDeskPrimary, IAssetDeskConfiguration, IAssetDeskErrors {
    /**
     * @dev Proves the contract is the asset desk one. A marker function.
     *
     * It is used for simple contract compliance checks, e.g. during an upgrade.
     * This avoids situations where a wrong contract address is specified by mistake.
     */
    function proveAssetDesk() external pure;
}
