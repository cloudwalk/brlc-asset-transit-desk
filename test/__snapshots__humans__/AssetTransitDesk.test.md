# AssetTransitDesk.test

## Usage example

| Idx | Caller | Contract | Name | Args |
| --- | ------ | -------- | ---- | ---- |
| 1 | manager | assetDesk | issueAsset | [account, 100] |
| 2 | manager | assetDesk | redeemAsset | [account, 100, 10] |

```mermaid
sequenceDiagram
  actor manager
  participant LP
  participant account
  participant assetDesk
  participant surplusTreasury
  rect rgb(230,255,230)
    manager->>assetDesk: manager calls assetDesk.issueAsset
    account-->>assetDesk: BRLC.Transfer: account -> assetDesk (100)
    assetDesk-->>LP: BRLC.Transfer: assetDesk -> LP (100)
    Note over LP: LP.Deposit
    Note over assetDesk: assetDesk.AssetIssued
  end
  rect rgb(230,255,230)
    manager->>assetDesk: manager calls assetDesk.redeemAsset
    LP-->>assetDesk: BRLC.Transfer: LP -> assetDesk (100)
    Note over LP: LP.Withdrawal
    surplusTreasury-->>assetDesk: BRLC.Transfer: surplusTreasury -> assetDesk (10)
    assetDesk-->>account: BRLC.Transfer: assetDesk -> account (110)
    Note over assetDesk: assetDesk.AssetRedeemed
  end
```

<details>
<summary>Step 0: assetDesk.issueAsset</summary>

- **type**: methodCall
- **caller**: manager
- **args**: `{
  "buyer": "account",
  "principalAmount": "100"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | BRLC | Transfer | `[account, assetDesk, 100]` |
| 2 | BRLC | Transfer | `[assetDesk, LP, 100]` |
| 3 | LP | Deposit | `[100]` |
| 4 | assetDesk | AssetIssued | `[account, 100]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| LP | 10100 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 9900 |
| surplusTreasury | 10000 |
| pauser | 0 |
| stranger | 0 |



</details>
<details>
<summary>Step 1: assetDesk.redeemAsset</summary>

- **type**: methodCall
- **caller**: manager
- **args**: `{
  "buyer": "account",
  "principalAmount": "100",
  "netYieldAmount": "10"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | BRLC | Transfer | `[LP, assetDesk, 100]` |
| 2 | LP | Withdrawal | `[100, 0]` |
| 3 | BRLC | Transfer | `[surplusTreasury, assetDesk, 10]` |
| 4 | BRLC | Transfer | `[assetDesk, account, 110]` |
| 5 | assetDesk | AssetRedeemed | `[account, 100, 10]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| LP | 10000 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 10010 |
| surplusTreasury | 9990 |
| pauser | 0 |
| stranger | 0 |



</details>

## Configuration

| Idx | Caller | Contract | Name | Args |
| --- | ------ | -------- | ---- | ---- |
| 1 | deployer | LP | grantRole | [0xa4980720..5693c21775, assetDesk] |
| 2 | surplusTreasury | BRLC | approve | [assetDesk, 10000] |
| 3 | deployer | assetDesk | setLiquidityPool | [LP] |
| 4 | deployer | assetDesk | setSurplusTreasury | [surplusTreasury] |

```mermaid
sequenceDiagram
  actor deployer
  actor surplusTreasury
  participant BRLC
  participant LP
  participant assetDesk
  rect rgb(230,255,230)
    deployer->>LP: deployer calls LP.grantRole
    Note over assetDesk: assetDesk.RoleGranted
  end
  rect rgb(230,255,230)
    surplusTreasury->>BRLC: surplusTreasury calls BRLC.approve
    Note over BRLC: BRLC.Approval
  end
  rect rgb(230,255,230)
    deployer->>assetDesk: deployer calls assetDesk.setLiquidityPool
    Note over BRLC: BRLC.Approval
    Note over assetDesk: assetDesk.LiquidityPoolChanged
  end
  rect rgb(230,255,230)
    deployer->>assetDesk: deployer calls assetDesk.setSurplusTreasury
    Note over assetDesk: assetDesk.SurplusTreasuryChanged
  end
```

<details>
<summary>Step 0: LP.grantRole</summary>

- **type**: methodCall
- **caller**: deployer
- **args**: `{
  "role": "0xa4980720..5693c21775",
  "account": "assetDesk"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | assetDesk | RoleGranted | `[0xa4980720..5693c21775, assetDesk, deployer]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>
<details>
<summary>Step 1: BRLC.approve</summary>

- **type**: methodCall
- **caller**: surplusTreasury
- **args**: `{
  "spender": "assetDesk",
  "value": "10000"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | BRLC | Approval | `[surplusTreasury, assetDesk, 10000]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>
<details>
<summary>Step 2: assetDesk.setLiquidityPool</summary>

- **type**: methodCall
- **caller**: deployer
- **args**: `{
  "newLiquidityPool": "LP"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | BRLC | Approval | `[assetDesk, LP, 1157920892..3129639935]` |
| 2 | assetDesk | LiquidityPoolChanged | `[LP, ZERO_ADDR]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>
<details>
<summary>Step 3: assetDesk.setSurplusTreasury</summary>

- **type**: methodCall
- **caller**: deployer
- **args**: `{
  "newSurplusTreasury": "surplusTreasury"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | assetDesk | SurplusTreasuryChanged | `[surplusTreasury, ZERO_ADDR]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>

