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
import { ILiquidityPool } from "./interfaces/ILiquidityPool.sol";

import { AssetTransitDeskStorageLayout } from "./AssetTransitDeskStorageLayout.sol";

/**
 * @title AssetTransitDesk contract
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
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
     * - Caller must have the {MANAGER_ROLE} role.
     * - `buyer` must not be the zero address.
     * - `principalAmount` must be greater than zero.
     * - Contract must not be paused.
     */
    function issueAsset(
        bytes32 assetDepositId,
        address buyer,
        uint64 principalAmount
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        if (buyer == address(0)) {
            revert AssetTransitDesk_BuyerAddressZero();
        }

        if (principalAmount == 0) {
            revert AssetTransitDesk_PrincipalAmountZero();
        }

        AssetTransitDeskStorage storage $ = _getAssetTransitDeskStorage();

        if ($.issueOperations[assetDepositId].status != OperationStatus.Nonexistent) {
            revert AssetTransitDesk_OperationAlreadyExists();
        }

        IERC20($.token).safeTransferFrom(buyer, address(this), principalAmount);
        ILiquidityPool($.liquidityPool).depositFromWorkingTreasury(address(this), principalAmount);

        $.issueOperations[assetDepositId] = IssueOperation({
            status: OperationStatus.Successful,
            buyer: buyer,
            principalAmount: principalAmount
        });

        emit AssetIssued(assetDepositId, buyer, principalAmount);
    }

    /**
     * @inheritdoc IAssetTransitDeskPrimary
     *
     * @dev Requirements:
     * - Caller must have the {MANAGER_ROLE} role.
     * - `buyer` must not be the zero address.
     * - `principalAmount` must be greater than zero.
     * - `netYieldAmount` must be greater than zero.
     * - Contract must not be paused.
     */
    function redeemAsset(
        bytes32 assetRedemptionId,
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

        if ($.redeemOperations[assetRedemptionId].status != OperationStatus.Nonexistent) {
            revert AssetTransitDesk_OperationAlreadyExists();
        }

        ILiquidityPool($.liquidityPool).withdrawToWorkingTreasury(address(this), principalAmount);
        IERC20($.token).safeTransferFrom($.surplusTreasury, address(this), netYieldAmount);
        IERC20($.token).safeTransfer(buyer, principalAmount + netYieldAmount);

        $.redeemOperations[assetRedemptionId] = RedeemOperation({
            status: OperationStatus.Successful,
            buyer: buyer,
            principalAmount: principalAmount,
            netYieldAmount: netYieldAmount
        });

        emit AssetRedeemed(assetRedemptionId, buyer, principalAmount, netYieldAmount);
    }

    /**
     * @inheritdoc IAssetTransitDeskConfiguration
     *
     * @dev Requirements:
     * - Caller must have the {OWNER_ROLE} role.
     * - `newSurplusTreasury` must not be the zero address.
     * - `newSurplusTreasury` must differ from the current value.
     * - `newSurplusTreasury` must grant allowance to this contract for the underlying token.
     */
    function setSurplusTreasury(address newSurplusTreasury) external onlyRole(OWNER_ROLE) {
        AssetTransitDeskStorage storage $ = _getAssetTransitDeskStorage();
        address oldSurplusTreasury = $.surplusTreasury;

        _validateTreasuryChange(newSurplusTreasury, oldSurplusTreasury);

        if (IERC20($.token).allowance(newSurplusTreasury, address(this)) == 0) {
            revert AssetTransitDesk_TreasuryAllowanceZero();
        }

        $.surplusTreasury = newSurplusTreasury;

        emit SurplusTreasuryChanged(newSurplusTreasury, oldSurplusTreasury);
    }

    /**
     * @inheritdoc IAssetTransitDeskConfiguration
     *
     * @dev Requirements:
     * - Caller must have the {OWNER_ROLE} role.
     * - `newLiquidityPool` must not be the zero address.
     * - `newLiquidityPool` must differ from the current value.
     * - `newLiquidityPool` must grant allowance to this contract for the underlying token.
     */
    function setLiquidityPool(address newLiquidityPool) external onlyRole(OWNER_ROLE) {
        AssetTransitDeskStorage storage $ = _getAssetTransitDeskStorage();
        address oldLiquidityPool = $.liquidityPool;

        _validateTreasuryChange(newLiquidityPool, oldLiquidityPool);
        _validateLiquidityPool(newLiquidityPool);

        $.liquidityPool = newLiquidityPool;

        emit LiquidityPoolChanged(newLiquidityPool, oldLiquidityPool);
    }

    /**
     * @inheritdoc IAssetTransitDeskConfiguration
     *
     * @dev Requirements:
     * - Caller must have the {OWNER_ROLE} role.
     */
    function approve(address spender, uint256 amount) external onlyRole(OWNER_ROLE) {
        AssetTransitDeskStorage storage $ = _getAssetTransitDeskStorage();
        IERC20($.token).approve(spender, amount);
    }

    // ------------------ View functions -------------------------- //

    /// @inheritdoc IAssetTransitDeskPrimary
    function getIssueOperation(bytes32 assetDepositId) external view returns (IssueOperationView memory) {
        IssueOperation storage operation = _getAssetTransitDeskStorage().issueOperations[assetDepositId];

        return
            IssueOperationView({
                status: operation.status,
                buyer: operation.buyer,
                principalAmount: operation.principalAmount
            });
    }

    /// @inheritdoc IAssetTransitDeskPrimary
    function getRedeemOperation(bytes32 assetRedemptionId) external view returns (RedeemOperationView memory) {
        RedeemOperation storage operation = _getAssetTransitDeskStorage().redeemOperations[assetRedemptionId];

        return
            RedeemOperationView({
                status: operation.status,
                buyer: operation.buyer,
                principalAmount: operation.principalAmount,
                netYieldAmount: operation.netYieldAmount
            });
    }

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

    function _validateTreasuryChange(address newTreasury, address oldTreasury) internal pure {
        if (newTreasury == oldTreasury) {
            revert AssetTransitDesk_TreasuryAlreadyConfigured();
        }
        if (newTreasury == address(0)) {
            revert AssetTransitDesk_TreasuryAddressZero();
        }
    }

    function _validateLiquidityPool(address newLiquidityPool) internal view {
        if (newLiquidityPool.code.length == 0) {
            revert AssetTransitDesk_LiquidityPoolAddressInvalid();
        }

        try ILiquidityPool(newLiquidityPool).proveLiquidityPool() {} catch {
            revert AssetTransitDesk_LiquidityPoolAddressInvalid();
        }
        if (ILiquidityPool(newLiquidityPool).token() != _getAssetTransitDeskStorage().token) {
            revert AssetTransitDesk_LiquidityPoolTokenMismatch();
        }

        if (!AccessControlExtUpgradeable(newLiquidityPool).hasRole(keccak256("ADMIN_ROLE"), address(this))) {
            revert AssetTransitDesk_LiquidityPoolNotAdmin();
        }

        address[] memory workingTreasuries = ILiquidityPool(newLiquidityPool).workingTreasuries();
        for (uint256 i = 0; i < workingTreasuries.length; i++) {
            if (workingTreasuries[i] == address(this)) {
                return;
            }
        }

        revert AssetTransitDesk_ContractNotRegisteredAsWorkingTreasury();
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
