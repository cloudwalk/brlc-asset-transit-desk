// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/**
 * @title ILiquidityPool interface
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev The liquidity pool contract interface.
 * See https://github.com/cloudwalk/brlc-capybara-finance/blob/main/contracts/interfaces/ILiquidityPool.sol
 */
interface ILiquidityPool {
    // ------------------ Events ---------------------------------- //

    event Deposit(uint256 amount);

    event Withdrawal(uint256 borrowableAmount, uint256 addonAmount);

    function depositFromWorkingTreasury(address treasury, uint256 amount) external;

    function withdrawToWorkingTreasury(address treasury, uint256 amount) external;

    function token() external view returns (address);

    function workingTreasuries() external view returns (address[] memory);

    function proveLiquidityPool() external pure;
}
