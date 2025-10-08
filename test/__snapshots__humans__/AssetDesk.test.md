# AssetDesk.test

## simple scenario

| Idx | Caller | Contract | Name | Args |
| --- | ------ | -------- | ---- | ---- |
| 1 | manager | assetDesk | issueAsset | [account, 100] |
| 2 | manager | assetDesk | redeemAsset | [account, 100, 10, 1] |

```mermaid
sequenceDiagram
  actor manager
  participant account
  participant assetDesk
  participant lpTreasury
  participant surplusTreasury
  participant taxTreasury
  rect rgb(230,255,230)
    manager->>assetDesk: manager calls assetDesk.issueAsset
    account-->>assetDesk: brlc.Transfer: account -> assetDesk (100)
    assetDesk-->>lpTreasury: brlc.Transfer: assetDesk -> lpTreasury (100)
    Note over assetDesk: assetDesk.AssetIssued
  end
  rect rgb(230,255,230)
    manager->>assetDesk: manager calls assetDesk.redeemAsset
    lpTreasury-->>assetDesk: brlc.Transfer: lpTreasury -> assetDesk (100)
    surplusTreasury-->>assetDesk: brlc.Transfer: surplusTreasury -> assetDesk (11)
    assetDesk-->>account: brlc.Transfer: assetDesk -> account (110)
    assetDesk-->>taxTreasury: brlc.Transfer: assetDesk -> taxTreasury (1)
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
| 1 | brlc | Transfer | `[account, assetDesk, 100]` |
| 2 | brlc | Transfer | `[assetDesk, lpTreasury, 100]` |
| 3 | assetDesk | AssetIssued | `[account, 100]` |

**Balances**

**Token:** brlc
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| brlc | 0 |
| deployer | 0 |
| manager | 0 |
| account | 9900 |
| lpTreasury | 10100 |
| surplusTreasury | 10000 |
| taxTreasury | 0 |
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
  "netYieldAmount": "10",
  "taxAmount": "1"
}`

**Events**

| # | Contract | Event | Args |
| - | -------- | ----- | ---- |
| 1 | brlc | Transfer | `[lpTreasury, assetDesk, 100]` |
| 2 | brlc | Transfer | `[surplusTreasury, assetDesk, 11]` |
| 3 | brlc | Transfer | `[assetDesk, account, 110]` |
| 4 | brlc | Transfer | `[assetDesk, taxTreasury, 1]` |
| 5 | assetDesk | AssetRedeemed | `[account, 100, 10, 1]` |

**Balances**

**Token:** brlc
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| brlc | 0 |
| deployer | 0 |
| manager | 0 |
| account | 10010 |
| lpTreasury | 10000 |
| surplusTreasury | 9989 |
| taxTreasury | 1 |
| pauser | 0 |
| stranger | 0 |



</details>

