## Main Changes

- Added operation identifiers to prevent duplicate execution and improve traceability.
  - Breaking change: function signatures now require IDs as the first argument.
    - `depositAsset(bytes32 assetDepositId, address buyer, uint64 principalAmount)`
    - `redeemAsset(bytes32 assetRedemptionId, address buyer, uint64 principalAmount, uint64 netYieldAmount)`

- Updated events to include and index operation IDs and buyer for efficient querying:
  - `AssetDeposited(bytes32 indexed assetDepositId, address indexed buyer, uint64 principalAmount)`
  - `AssetRedeemed(bytes32 indexed assetRedemptionId, address indexed buyer, uint64 principalAmount, uint64 netYieldAmount)`

- Added view functions to inspect recorded operations:
  - `getDepositOperation(bytes32 assetDepositId) → (status, buyer, principalAmount)`
  - `getRedemptionOperation(bytes32 assetRedemptionId) → (status, buyer, principalAmount, netYieldAmount)`

- Added custom error to enforce idempotency:
  - `AssetTransitDesk_OperationAlreadyExists()`

# 1.0.0

## Introduced AssetTransitDesk contract

- Orchestrate deposits and redemptions of CDBs.

### Behavior
- **Deposit**: `depositAsset(buyer, principal)`
  - Pulls `principal` from `buyer` to this contract (requires allowance).
  - Deposits `principal` to `liquidityPool` from this contract as a working treasury.
  - Emits `AssetIssued(buyer, principal)`.
- **Redeem**: `redeemAsset(buyer, principal, netYield)`
  - Withdraws `principal` from `liquidityPool` back to this contract.
  - Pulls `netYield` from `surplusTreasury` to this contract (requires allowance).
  - Pays `buyer` `principal + netYield`.
  - Emits `AssetRedeemed(buyer, principal, netYield)`.

### Public/External API
- `depositAsset(address buyer, uint64 principalAmount)` — manager-only, when not paused.
- `redeemAsset(address buyer, uint64 principalAmount, uint64 netYieldAmount)` — manager-only, when not paused.
- `setSurplusTreasury(address newSurplusTreasury)` — owner-only.
- `setLiquidityPool(address newLiquidityPool)` — owner-only.
- `approve(address spender, uint256 amount)` — owner-only.
- `getSurplusTreasury() → address` — view.
- `getLiquidityPool() → address` — view.
- `underlyingToken() → address` — view.

### Events
- `AssetIssued(address buyer, uint64 principalAmount)`
- `AssetRedeemed(address buyer, uint64 principalAmount, uint64 netYieldAmount)`
- `SurplusTreasuryChanged(address newSurplusTreasury, address oldSurplusTreasury)`
- `LiquidityPoolChanged(address newLiquidityPool, address oldLiquidityPool)`

### Roles & Access Control
- `OWNER_ROLE` (admin: `OWNER_ROLE`):
  - Can set `surplusTreasury`, set `liquidityPool`, authorize upgrades.
- `GRANTOR_ROLE` (admin: `OWNER_ROLE`):
  - Admin for `MANAGER_ROLE`, `PAUSER_ROLE`, `RESCUER_ROLE`.
- `MANAGER_ROLE` (admin: `GRANTOR_ROLE`):
  - Can `depositAsset`, `redeemAsset` when not paused.
- `PAUSER_ROLE` (admin: `GRANTOR_ROLE`):
  - Can `pause`/`unpause`.
- `RESCUER_ROLE` (admin: `GRANTOR_ROLE`):
  - Can `rescueERC20`.

### Custom Errors
- `AssetTransitDesk_BuyerAddressZero()`
- `AssetTransitDesk_ContractNotRegisteredAsWorkingTreasury()`
- `AssetTransitDesk_ImplementationAddressInvalid()`
- `AssetTransitDesk_LiquidityPoolAddressInvalid()`
- `AssetTransitDesk_LiquidityPoolNotAdmin()`
- `AssetTransitDesk_LiquidityPoolTokenMismatch()`
- `AssetTransitDesk_NetYieldAmountZero()`
- `AssetTransitDesk_PrincipalAmountZero()`
- `AssetTransitDesk_TokenAddressZero()`
- `AssetTransitDesk_TreasuryAddressZero()`
- `AssetTransitDesk_TreasuryAllowanceZero()`
- `AssetTransitDesk_TreasuryAlreadyConfigured()`

### Operational Setup
- Ensure `surplusTreasury` approves this contract for the underlying token (non-zero allowance required).
- Ensure the chosen `liquidityPool` uses the same underlying token, this contract holds pool `ADMIN_ROLE`, and it’s registered as a working treasury in the pool.
- Grant `MANAGER_ROLE`, `PAUSER_ROLE`, and `RESCUER_ROLE` to operational accounts via owner/grantor as appropriate.
- Buyer must approve this contract to spend their tokens.

### Security Notes
- All state changes are role-gated; deposit/redemption guarded by `whenNotPaused`.
- Pool address is strictly validated to prevent misconfiguration or token mismatch.
- No automatic allowance is granted on pool change; approvals are explicit and owner-controlled via `approve`.
