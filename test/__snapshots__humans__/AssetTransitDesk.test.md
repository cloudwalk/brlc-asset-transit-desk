# AssetTransitDesk.test

## Usage example

| Idx | Caller | Contract | Name | Args |
| --- | ------ | -------- | ---- | ---- |
| 1 | manager | assetTransitDesk | issueAsset | [account, 100] |
| 2 | manager | assetTransitDesk | redeemAsset | [account, 100, 10] |

```mermaid
sequenceDiagram
  actor manager
  participant LP
  participant account
  participant assetTransitDesk
  participant surplusTreasury
  rect rgb(230,255,230)
    manager->>assetTransitDesk: manager calls assetTransitDesk.issueAsset
    account-->>assetTransitDesk: BRLC.Transfer: account -> assetTransitDesk (100)
    assetTransitDesk-->>LP: BRLC.Transfer: assetTransitDesk -> LP (100)
    Note over LP: LP.Deposit
    Note over assetTransitDesk: assetTransitDesk.AssetIssued
  end
  rect rgb(230,255,230)
    manager->>assetTransitDesk: manager calls assetTransitDesk.redeemAsset
    LP-->>assetTransitDesk: BRLC.Transfer: LP -> assetTransitDesk (100)
    Note over LP: LP.Withdrawal
    surplusTreasury-->>assetTransitDesk: BRLC.Transfer: surplusTreasury -> assetTransitDesk (10)
    assetTransitDesk-->>account: BRLC.Transfer: assetTransitDesk -> account (110)
    Note over assetTransitDesk: assetTransitDesk.AssetRedeemed
  end
```

<details>
<summary>Step 0: assetTransitDesk.issueAsset</summary>

- **type**: methodCall
- **caller**: manager
- **args**: `{
  "buyer": "account",
  "principalAmount": "100"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | BRLC | Transfer | `[account, assetTransitDesk, 100]` |
| 2 | BRLC | Transfer | `[assetTransitDesk, LP, 100]` |
| 3 | LP | Deposit | `[100]` |
| 4 | assetTransitDesk | AssetIssued | `[account, 100]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetTransitDesk | 0 |
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
<summary>Step 1: assetTransitDesk.redeemAsset</summary>

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
| 1 | BRLC | Transfer | `[LP, assetTransitDesk, 100]` |
| 2 | LP | Withdrawal | `[100, 0]` |
| 3 | BRLC | Transfer | `[surplusTreasury, assetTransitDesk, 10]` |
| 4 | BRLC | Transfer | `[assetTransitDesk, account, 110]` |
| 5 | assetTransitDesk | AssetRedeemed | `[account, 100, 10]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetTransitDesk | 0 |
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
| 1 | deployer | LP | grantRole | [0xa4980720..5693c21775, assetTransitDesk] |
| 2 | deployer | LP | setWorkingTreasuries | [[assetTransitDesk]] |
| 3 | surplusTreasury | BRLC | approve | [assetTransitDesk, 10000] |
| 4 | deployer | assetTransitDesk | setLiquidityPool | [LP] |
| 5 | deployer | assetTransitDesk | setSurplusTreasury | [surplusTreasury] |

```mermaid
sequenceDiagram
  actor deployer
  actor surplusTreasury
  participant BRLC
  participant LP
  participant assetTransitDesk
  rect rgb(230,255,230)
    deployer->>LP: deployer calls LP.grantRole
    Note over LP: LP.RoleGranted
  end
  rect rgb(230,255,230)
    deployer->>LP: deployer calls LP.setWorkingTreasuries
  end
  rect rgb(230,255,230)
    surplusTreasury->>BRLC: surplusTreasury calls BRLC.approve
    Note over BRLC: BRLC.Approval
  end
  rect rgb(230,255,230)
    deployer->>assetTransitDesk: deployer calls assetTransitDesk.setLiquidityPool
    Note over BRLC: BRLC.Approval
    Note over assetTransitDesk: assetTransitDesk.LiquidityPoolChanged
  end
  rect rgb(230,255,230)
    deployer->>assetTransitDesk: deployer calls assetTransitDesk.setSurplusTreasury
    Note over assetTransitDesk: assetTransitDesk.SurplusTreasuryChanged
  end
```

<details>
<summary>Step 0: LP.grantRole</summary>

- **type**: methodCall
- **caller**: deployer
- **args**: `{
  "role": "0xa4980720..5693c21775",
  "account": "assetTransitDesk"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | LP | RoleGranted | `[0xa4980720..5693c21775, assetTransitDesk, deployer]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetTransitDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>
<details>
<summary>Step 1: LP.setWorkingTreasuries</summary>

- **type**: methodCall
- **caller**: deployer
- **args**: `{
  "newWorkingTreasuries": "[assetTransitDesk]"
}`

**Events**

_No events_

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetTransitDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>
<details>
<summary>Step 2: BRLC.approve</summary>

- **type**: methodCall
- **caller**: surplusTreasury
- **args**: `{
  "spender": "assetTransitDesk",
  "value": "10000"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | BRLC | Approval | `[surplusTreasury, assetTransitDesk, 10000]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetTransitDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>
<details>
<summary>Step 3: assetTransitDesk.setLiquidityPool</summary>

- **type**: methodCall
- **caller**: deployer
- **args**: `{
  "newLiquidityPool": "LP"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | BRLC | Approval | `[assetTransitDesk, LP, 1157920892..3129639935]` |
| 2 | assetTransitDesk | LiquidityPoolChanged | `[LP, ZERO_ADDR]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetTransitDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>
<details>
<summary>Step 4: assetTransitDesk.setSurplusTreasury</summary>

- **type**: methodCall
- **caller**: deployer
- **args**: `{
  "newSurplusTreasury": "surplusTreasury"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | assetTransitDesk | SurplusTreasuryChanged | `[surplusTreasury, ZERO_ADDR]` |

**Balances**

**Token:** BRLC
| Holder | Balance |
| ------ | ------- |
| assetTransitDesk | 0 |
| LP | 0 |
| BRLC | 0 |
| deployer | 0 |
| manager | 0 |
| account | 0 |
| surplusTreasury | 0 |



</details>

