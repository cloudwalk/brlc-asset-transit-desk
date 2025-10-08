// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/**
 * @title IAssetTransitDeskPrimary interface
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev The primary part of the AssetTransitDesk smart contract interface.
 */
interface IAssetTransitDeskPrimary {
    // ------------------ Events ---------------------------------- //

    /**
     * @dev Emitted when an asset is issued.
     *
     * @param buyer The address of the buyer.
     * @param principalAmount The amount of the principal.
     */
    event AssetIssued(address buyer, uint64 principalAmount);

    /**
     * @dev Emitted when an asset is redeemed.
     *
     * @param buyer The address of the buyer.
     * @param principalAmount The amount of the principal.
     * @param netYieldAmount The amount of the net yield.
     */
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
 * @dev The configuration part of the AssetTransitDesk smart contract interface.
 */
interface IAssetTransitDeskConfiguration {
    // ------------------ Events ---------------------------------- //

    /**
     * @dev Emitted when the surplus treasury address is changed.
     *
     * @param newSurplusTreasury The new address of the surplus treasury.
     * @param oldSurplusTreasury The old address of the surplus treasury.
     */
    event SurplusTreasuryChanged(address newSurplusTreasury, address oldSurplusTreasury);

    /**
     * @dev Emitted when the liquidity pool address is changed.
     *
     * @param newLiquidityPool The new address of the liquidity pool.
     * @param oldLiquidityPool The old address of the liquidity pool.
     */
    event LiquidityPoolChanged(address newLiquidityPool, address oldLiquidityPool);

    // ------------------ Transactional functions ----------------- //

    /**
     * @dev Sets the surplus treasury address.
     *
     * Emits a {SurplusTreasuryChanged} event.
     *
     * @param newSurplusTreasury The new address of the surplus treasury to set.
     */
    function setSurplusTreasury(address newSurplusTreasury) external;

    /**
     * @dev Sets the liquidity pool address.
     *
     * Emits a {LiquidityPoolChanged} event.
     *
     * @param newLiquidityPool The new address of the liquidity pool to set.
     */
    function setLiquidityPool(address newLiquidityPool) external;

    // ------------------ View functions -------------------------- //

    /**
     * @dev Returns the address of the surplus treasury.
     *
     * @return The address of the surplus treasury.
     */
    function getSurplusTreasury() external view returns (address);

    /**
     * @dev Returns the address of the liquidity pool.
     *
     * @return The address of the liquidity pool.
     */
    function getLiquidityPool() external view returns (address);

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

    /// @dev Thrown if the provided new implementation address is not an AssetTransitDesk contract.
    error AssetTransitDesk_ImplementationAddressInvalid();

    /// @dev Thrown if the provided liquidity pool address is not an LiquidityPool contract.
    error AssetTransitDesk_LiquidityPoolAddressInvalid();

    /// @dev Thrown if the current contract is not an admin of the provided liquidity pool.
    error AssetTransitDesk_LiquidityPoolNotAdmin();

    /// @dev Thrown if the provided liquidity pool is not registered as a working treasury.
    error AssetTransitDesk_LiquidityPoolNotRegisteredAsWorkingTreasury();

    /// @dev Thrown if the provided liquidity pool token does not match the underlying token.
    error AssetTransitDesk_LiquidityPoolTokenMismatch();

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
 * @dev The full interface of the AssetTransitDesk smart contract.
 *
 * The smart contract manages and logs token transfers related to CDB buying and selling operations.
 */
interface IAssetTransitDesk is IAssetTransitDeskPrimary, IAssetTransitDeskConfiguration, IAssetTransitDeskErrors {
    /**
     * @dev Proves the contract is the AssetTransitDesk one. A marker function.
     *
     * It is used for simple contract compliance checks, e.g., during an upgrade.
     * This avoids situations where a wrong contract address is specified by mistake.
     */
    function proveAssetTransitDesk() external pure;
}
