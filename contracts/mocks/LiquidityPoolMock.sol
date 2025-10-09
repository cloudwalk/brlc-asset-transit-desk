// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ILiquidityPool } from "../interfaces/ILiquidityPool.sol";
import { AccessControlExtUpgradeable } from "../base/AccessControlExtUpgradeable.sol";

/**
 * @title LiquidityPoolMock contract
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev An implementation of the {ILiquidityPool} contract for test purposes.
 */
contract LiquidityPoolMock is ILiquidityPool, AccessControlExtUpgradeable, UUPSUpgradeable {
    // ------------------ Storage variables ------------------------ //

    address private _token;
    address[] private _workingTreasuries;

    // ------------------ Constants ------------------------------- //

    /// @dev The role of an admin that is allowed to execute loan-related functions except the correction one.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // ------------------ Initializers ---------------------------- //

    /**
     * @dev Initializer of the upgradeable contract.
     *
     * See details: https://docs.openzeppelin.com/upgrades-plugins/writing-upgradeable
     */
    function initialize(address token_, address[] memory workingTreasuries_) public initializer {
        __AccessControlExt_init_unchained();

        _token = token_;
        _workingTreasuries = workingTreasuries_;

        _grantRole(OWNER_ROLE, _msgSender());
        _grantRole(GRANTOR_ROLE, _msgSender());
        _setRoleAdmin(ADMIN_ROLE, GRANTOR_ROLE);

        // Only to provide 100% test coverage
        _authorizeUpgrade(address(0));
    }

    // ------------------ Transactional functions ----------------- //

    /// @inheritdoc ILiquidityPool
    function depositFromWorkingTreasury(address treasury, uint256 amount) external onlyRole(ADMIN_ROLE) {
        IERC20(_token).transferFrom(treasury, address(this), amount);
        emit Deposit(amount);
    }

    /// @inheritdoc ILiquidityPool
    function withdrawToWorkingTreasury(address treasury, uint256 amount) external onlyRole(ADMIN_ROLE) {
        IERC20(_token).transfer(treasury, amount);
        emit Withdrawal(amount, 0);
    }

    function setWorkingTreasuries(address[] memory newWorkingTreasuries) external {
        _workingTreasuries = newWorkingTreasuries;
    }

    function setToken(address newToken) external {
        _token = newToken;
    }

    // ------------------ View functions -------------------------- //

    /// @inheritdoc ILiquidityPool
    function proveLiquidityPool() external pure {}

    /// @inheritdoc ILiquidityPool
    function workingTreasuries() external view returns (address[] memory) {
        return _workingTreasuries;
    }

    /// @inheritdoc ILiquidityPool
    function token() external view returns (address) {
        return _token;
    }

    // ------------------ Internal functions ---------------------- //

    /**
     * @dev The implementation of the upgrade authorization function of the parent UUPSUpgradeable contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal pure override {
        newImplementation; // Suppresses a compiler warning about the unused variable.
    }
}
