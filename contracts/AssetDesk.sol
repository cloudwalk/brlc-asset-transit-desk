// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { AccessControlExtUpgradeable } from "./base/AccessControlExtUpgradeable.sol";
import { PausableExtUpgradeable } from "./base/PausableExtUpgradeable.sol";
import { RescuableUpgradeable } from "./base/RescuableUpgradeable.sol";
import { Versionable } from "./base/Versionable.sol";
import { UUPSExtUpgradeable } from "./base/UUPSExtUpgradeable.sol";

import { IAssetDesk } from "./interfaces/IAssetDesk.sol";
import { IAssetDeskPrimary } from "./interfaces/IAssetDesk.sol";
import { IAssetDeskConfiguration } from "./interfaces/IAssetDesk.sol";
import { IAssetDeskErrors } from "./interfaces/IAssetDesk.sol";

import { AssetDeskStorageLayout } from "./AssetDeskStorageLayout.sol";

/**
 * @title AssetDesk contract
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev The smart contract is designed as a reference and template one.
 * It executes issue and redeem CDB operations.
 *
 * See details about the contract in the comments of the {IAssetDesk} interface.
 */
contract AssetDesk is
    AssetDeskStorageLayout,
    AccessControlExtUpgradeable,
    PausableExtUpgradeable,
    RescuableUpgradeable,
    UUPSExtUpgradeable,
    Versionable,
    IAssetDesk
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
        __AccessControlExt_init_unchained();
        __PausableExt_init_unchained();
        __Rescuable_init_unchained();
        __UUPSExt_init_unchained(); // This is needed only to avoid errors during coverage assessment

        if (token_ == address(0)) {
            revert AssetDesk_TokenAddressZero();
        }

        _getAssetDeskStorage().token = token_;

        _setRoleAdmin(MANAGER_ROLE, GRANTOR_ROLE);
        _grantRole(OWNER_ROLE, _msgSender());
    }

    // ------------------ Transactional functions ----------------- //
    /**
     * @inheritdoc IAssetDeskPrimary
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
            revert AssetDesk_BuyerAddressZero();
        }
        if (principalAmount == 0) {
            revert AssetDesk_PrincipalAmountZero();
        }

        AssetDeskStorage storage $ = _getAssetDeskStorage();

        IERC20($.token).safeTransferFrom(buyer, address(this), principalAmount);
        IERC20($.token).safeTransfer($.lpTreasury, principalAmount);

        emit AssetIssued(buyer, principalAmount);
    }

    /**
     * @inheritdoc IAssetDeskPrimary
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
        uint64 netYieldAmount,
        uint64 taxAmount
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        if (buyer == address(0)) {
            revert AssetDesk_BuyerAddressZero();
        }
        if (principalAmount == 0) {
            revert AssetDesk_PrincipalAmountZero();
        }
        if (netYieldAmount == 0) {
            revert AssetDesk_NetYieldAmountZero();
        }
        if (taxAmount == 0) {
            revert AssetDesk_TaxAmountZero();
        }

        AssetDeskStorage storage $ = _getAssetDeskStorage();

        IERC20($.token).safeTransferFrom($.lpTreasury, address(this), principalAmount);
        IERC20($.token).safeTransferFrom($.surplusTreasury, address(this), netYieldAmount + taxAmount);
        IERC20($.token).safeTransfer(buyer, principalAmount + netYieldAmount);
        IERC20($.token).safeTransfer($.taxTreasury, taxAmount);

        emit AssetRedeemed(buyer, principalAmount, netYieldAmount, taxAmount);
    }

    /**
     * @inheritdoc IAssetDeskConfiguration
     *
     * @dev Requirements:
     *
     * - The caller must have the {OWNER_ROLE} role.
     * - The new surplus treasury address must not be zero.
     * - The new surplus treasury address must not be the same as already configured.
     * - The new surplus treasury address must have granted the contract allowance to spend tokens.
     */
    function setSurplusTreasury(address newSurplusTreasury) external onlyRole(OWNER_ROLE) {
        AssetDeskStorage storage $ = _getAssetDeskStorage();
        address oldTreasury = $.surplusTreasury;
        if (newSurplusTreasury == oldTreasury) {
            revert AssetDesk_TreasuryAlreadyConfigured();
        }
        if (newSurplusTreasury == address(0)) {
            revert AssetDesk_TreasuryZero();
        }
        if (IERC20($.token).allowance(newSurplusTreasury, address(this)) == 0) {
            revert AssetDesk_TreasuryAllowanceZero();
        }

        emit SurplusTreasuryChanged(newSurplusTreasury, oldTreasury);
        $.surplusTreasury = newSurplusTreasury;
    }

    /**
     * @inheritdoc IAssetDeskConfiguration
     *
     * @dev Requirements:
     *
     * - The caller must have the {OWNER_ROLE} role.
     * - The new LP treasury address must not be zero.
     * - The new LP treasury address must not be the same as already configured.
     * - The new LP treasury address must have granted the contract allowance to spend tokens.
     */
    function setLPTreasury(address newLPTreasury) external onlyRole(OWNER_ROLE) {
        AssetDeskStorage storage $ = _getAssetDeskStorage();
        address oldTreasury = $.lpTreasury;
        if (newLPTreasury == oldTreasury) {
            revert AssetDesk_TreasuryAlreadyConfigured();
        }
        if (newLPTreasury == address(0)) {
            revert AssetDesk_TreasuryZero();
        }
        if (IERC20($.token).allowance(newLPTreasury, address(this)) == 0) {
            revert AssetDesk_TreasuryAllowanceZero();
        }

        emit LPTreasuryChanged(newLPTreasury, oldTreasury);
        $.lpTreasury = newLPTreasury;
    }

    /**
     * @inheritdoc IAssetDeskConfiguration
     *
     * @dev Requirements:
     *
     * - The caller must have the {OWNER_ROLE} role.
     * - The new tax treasury address must not be zero.
     * - The new tax treasury address must not be the same as already configured.
     */
    function setTaxTreasury(address newTaxTreasury) external onlyRole(OWNER_ROLE) {
        AssetDeskStorage storage $ = _getAssetDeskStorage();
        address oldTreasury = $.taxTreasury;
        if (newTaxTreasury == oldTreasury) {
            revert AssetDesk_TreasuryAlreadyConfigured();
        }
        if (newTaxTreasury == address(0)) {
            revert AssetDesk_TreasuryZero();
        }

        emit TaxTreasuryChanged(newTaxTreasury, oldTreasury);
        $.taxTreasury = newTaxTreasury;
    }

    // ------------------ View functions -------------------------- //

    /// @inheritdoc IAssetDeskConfiguration
    function getSurplusTreasury() external view returns (address) {
        return _getAssetDeskStorage().surplusTreasury;
    }

    /// @inheritdoc IAssetDeskConfiguration
    function getLPTreasury() external view returns (address) {
        return _getAssetDeskStorage().lpTreasury;
    }

    /// @inheritdoc IAssetDeskConfiguration
    function getTaxTreasury() external view returns (address) {
        return _getAssetDeskStorage().taxTreasury;
    }

    /// @inheritdoc IAssetDeskConfiguration
    function underlyingToken() external view returns (address) {
        return _getAssetDeskStorage().token;
    }

    // ------------------ Pure functions -------------------------- //

    /// @inheritdoc IAssetDesk
    function proveAssetDesk() external pure {}

    // ------------------ Internal functions ---------------------- //

    /**
     * @dev The upgrade validation function for the UUPSExtUpgradeable contract.
     * @param newImplementation The address of the new implementation.
     */
    function _validateUpgrade(address newImplementation) internal view override onlyRole(OWNER_ROLE) {
        try IAssetDesk(newImplementation).proveAssetDesk() {} catch {
            revert AssetDesk_ImplementationAddressInvalid();
        }
    }
}
