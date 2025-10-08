// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/**
 * @title AssetTransitDeskStorageLayout contract
 * @author CloudWalk Inc. (See https://www.cloudwalk.io)
 * @dev Defines the storage layout for the reference smart-contract.
 *
 * See details about the contract in the comments of the {IAssetTransitDesk} interface.
 */
abstract contract AssetTransitDeskStorageLayout {
    // ------------------ Storage layout -------------------------- //

    /*
     * ERC-7201: Namespaced Storage Layout
     * keccak256(abi.encode(uint256(keccak256("cloudwalk.storage.AssetTransitDesk")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant ASSET_DESK_STORAGE_LOCATION =
        0x8d78a165cd67802614e6d2e1c779733003e05fa86c86bca1eacf388a6b1ca300;

    /**
     * @dev Defines the contract storage structure.
     *
     * Fields:
     *
     * - token ---------------- The address of the underlying token.
     * - surplusTreasury ------- The address of the surplus treasury.
     * - liquidityPool ------------ The address of the LP treasury.
     *
     * Notes:
     * 1. The surplus treasury is used to withdraw the yield.
     * 2. The LP treasury is used to withdraw and deposit the principal.
     *
     * @custom:storage-location erc7201:cloudwalk.storage.AssetTransitDesk
     */
    struct AssetTransitDeskStorage {
        // Slot 1
        address token;
        // uint96 __reserved1; // Reserved until the end of the storage slot

        // Slot 2
        address surplusTreasury;
        // uint96 __reserved1; // Reserved until the end of the storage slot

        // Slot 3
        address liquidityPool;
        // uint96 __reserved2;
    }

    // ------------------ Internal functions ---------------------- //

    /// @dev Returns the storage slot location for the `AssetTransitDeskStorage` struct.
    function _getAssetTransitDeskStorage() internal pure returns (AssetTransitDeskStorage storage $) {
        assembly {
            $.slot := ASSET_DESK_STORAGE_LOCATION
        }
    }
}
