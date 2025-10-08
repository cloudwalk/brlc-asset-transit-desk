// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { AccessControlExtUpgradeable } from "./base/AccessControlExtUpgradeable.sol";
import { PausableExtUpgradeable } from "./base/PausableExtUpgradeable.sol";
import { RescuableUpgradeable } from "./base/RescuableUpgradeable.sol";
import { Versionable } from "./base/Versionable.sol";
import { UUPSExtUpgradeable } from "./base/UUPSExtUpgradeable.sol";

import { IAssetTransitDesk } from "./interfaces/IAssetTransitDesk.sol";
import { IAssetTransitDeskPrimary } from "./interfaces/IAssetTransitDesk.sol";
import { IAssetTransitDeskConfiguration } from "./interfaces/IAssetTransitDesk.sol";
import { IAssetTransitDeskErrors } from "./interfaces/IAssetTransitDesk.sol";

import { AssetTransitDeskStorageLayout } from "./AssetTransitDeskStorageLayout.sol";

/**
 * @title AssetTransitDesk contract
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev The smart contract is designed as a reference and template one.
 * It executes issue and redeem CDB operations.
 *
 * See details about the contract in the comments of the {IAssetTransitDesk} interface.
 */
contract AssetTransitDesk is
    AssetTransitDeskStorageLayout,
    AccessControlExtUpgradeable,
    PausableExtUpgradeable,
    RescuableUpgradeable,
    UUPSExtUpgradeable,
    Versionable,
    IAssetTransitDesk
{
    // ------------------ Types ----------------------------------- //

    using SafeERC20 for IERC20;

    // ------------------ Constants ------------------------------- //

    /// @dev The role of manager that is allowed to issue and redeem assets.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // ------------------ Constructor ----------------------------- //

    /**
     * @dev Constructor that prohibits the initialization of the implementation of the upgradeable contract.
     *
     * See details:
     * https://docs.openzeppelin.com/upgrades-plugins/writing-upgradeable#initializing_the_implementation_contract
     *
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    // ------------------ Initializers ---------------------------- //

    /**
     * @dev Initializer of the upgradeable contract.
     *
     * See details: https://docs.openzeppelin.com/upgrades-plugins/writing-upgradeable
     *
     * @param token_ The address of the token to set as the underlying one.
     */
    function initialize(address token_) external initializer {
        if (token_ == address(0)) {
            revert AssetTransitDesk_TokenAddressZero();
        }

        __AccessControlExt_init_unchained();
        __PausableExt_init_unchained();
        __Rescuable_init_unchained();
        __UUPSExt_init_unchained(); // This is needed only to avoid errors during coverage assessment

        _getAssetTransitDeskStorage().token = token_;

        _setRoleAdmin(MANAGER_ROLE, GRANTOR_ROLE);
        _grantRole(OWNER_ROLE, _msgSender());
    }

    // ------------------ Transactional functions ----------------- //
    /**
     * @inheritdoc IAssetTransitDeskPrimary
     *
     * @dev Requirements:
     *
     * - The caller must have the {MANAGER_ROLE} role.
     * - The buyer address must not be zero.
     * - The principal amount must not be zero.
     * - The contract must not be paused.
     */
    function issueAsset(address buyer, uint64 principalAmount) external whenNotPaused onlyRole(MANAGER_ROLE) {
        if (buyer == address(0)) {
            revert AssetTransitDesk_BuyerAddressZero();
        }

        if (principalAmount == 0) {
            revert AssetTransitDesk_PrincipalAmountZero();
        }

        AssetTransitDeskStorage storage $ = _getAssetTransitDeskStorage();

        IERC20($.token).safeTransferFrom(buyer, address(this), principalAmount);
        IERC20($.token).safeTransfer($.liquidityPool, principalAmount);

        emit AssetIssued(buyer, principalAmount);
    }

    /**
     * @inheritdoc IAssetTransitDeskPrimary
     *
     * @dev Requirements:
     *
     * - The caller must have the {MANAGER_ROLE} role.
     * - The buyer address must not be zero.
     * - The principal amount must not be zero.
     * - The net yield amount must not be zero.
     * - The tax amount must not be zero.
     * - The contract must not be paused.
     */
    function redeemAsset(
        address buyer,
        uint64 principalAmount,
        uint64 netYieldAmount
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        if (buyer == address(0)) {
            revert AssetTransitDesk_BuyerAddressZero();
        }

        if (principalAmount == 0) {
            revert AssetTransitDesk_PrincipalAmountZero();
        }

        if (netYieldAmount == 0) {
            revert AssetTransitDesk_NetYieldAmountZero();
        }

        AssetTransitDeskStorage storage $ = _getAssetTransitDeskStorage();

        IERC20($.token).safeTransferFrom($.liquidityPool, address(this), principalAmount);
        IERC20($.token).safeTransferFrom($.surplusTreasury, address(this), netYieldAmount);
        IERC20($.token).safeTransfer(buyer, principalAmount + netYieldAmount);

        emit AssetRedeemed(buyer, principalAmount, netYieldAmount);
    }

    /**
     * @inheritdoc IAssetTransitDeskConfiguration
     *
     * @dev Requirements:
     *
     * - The caller must have the {OWNER_ROLE} role.
     * - The new surplus treasury address must not be zero.
     * - The new surplus treasury address must not be the same as already configured.
     * - The new surplus treasury address must have granted the contract allowance to spend tokens.
     */
    function setSurplusTreasury(address newSurplusTreasury) external onlyRole(OWNER_ROLE) {
        AssetTransitDeskStorage storage $ = _getAssetTransitDeskStorage();
        _validateTreasuryChange(newSurplusTreasury, $.surplusTreasury, $.token);

        emit SurplusTreasuryChanged(newSurplusTreasury, $.surplusTreasury);
        $.surplusTreasury = newSurplusTreasury;
    }

    /**
     * @inheritdoc IAssetTransitDeskConfiguration
     *
     * @dev Requirements:
     *
     * - The caller must have the {OWNER_ROLE} role.
     * - The new liquidity pool address must not be zero.
     * - The new liquidity pool address must not be the same as already configured.
     * - The new liquidity pool address must have granted the contract allowance to spend tokens.
     */
    function setLiquidityPool(address newLiquidityPool) external onlyRole(OWNER_ROLE) {
        AssetTransitDeskStorage storage $ = _getAssetTransitDeskStorage();
        _validateTreasuryChange(newLiquidityPool, $.liquidityPool, $.token);

        emit LiquidityPoolChanged(newLiquidityPool, $.liquidityPool);
        $.liquidityPool = newLiquidityPool;
    }

    // ------------------ View functions -------------------------- //

    /// @inheritdoc IAssetTransitDeskConfiguration
    function getSurplusTreasury() external view returns (address) {
        return _getAssetTransitDeskStorage().surplusTreasury;
    }

    /// @inheritdoc IAssetTransitDeskConfiguration
    function getLiquidityPool() external view returns (address) {
        return _getAssetTransitDeskStorage().liquidityPool;
    }

    /// @inheritdoc IAssetTransitDeskConfiguration
    function underlyingToken() external view returns (address) {
        return _getAssetTransitDeskStorage().token;
    }

    // ------------------ Pure functions -------------------------- //

    /// @inheritdoc IAssetTransitDesk
    function proveAssetTransitDesk() external pure {}

    // ------------------ Internal functions ---------------------- //

    function _validateTreasuryChange(address newTreasury, address oldTreasury, address token) internal view {
        if (newTreasury == oldTreasury) {
            revert AssetTransitDesk_TreasuryAlreadyConfigured();
        }
        if (newTreasury == address(0)) {
            revert AssetTransitDesk_TreasuryZero();
        }
        if (IERC20(token).allowance(newTreasury, address(this)) == 0) {
            revert AssetTransitDesk_TreasuryAllowanceZero();
        }
    }

    /**
     * @dev The upgrade validation function for the UUPSExtUpgradeable contract.
     * @param newImplementation The address of the new implementation.
     */
    function _validateUpgrade(address newImplementation) internal view override onlyRole(OWNER_ROLE) {
        try IAssetTransitDesk(newImplementation).proveAssetTransitDesk() {} catch {
            revert AssetTransitDesk_ImplementationAddressInvalid();
        }
    }
}
