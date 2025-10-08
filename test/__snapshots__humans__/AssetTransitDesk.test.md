# AssetTransitDesk.test

## simple scenario

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
    account-->>assetDesk: brlc.Transfer: account -> assetDesk (100)
    assetDesk-->>LP: brlc.Transfer: assetDesk -> LP (100)
    Note over LP: LP.Deposit
    Note over assetDesk: assetDesk.AssetIssued
  end
  rect rgb(230,255,230)
    manager->>assetDesk: manager calls assetDesk.redeemAsset
    LP-->>assetDesk: brlc.Transfer: LP -> assetDesk (100)
    Note over LP: LP.Withdrawal
    surplusTreasury-->>assetDesk: brlc.Transfer: surplusTreasury -> assetDesk (10)
    assetDesk-->>account: brlc.Transfer: assetDesk -> account (110)
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
| 2 | brlc | Transfer | `[assetDesk, LP, 100]` |
| 3 | LP | Deposit | `[100]` |
| 4 | assetDesk | AssetIssued | `[account, 100]` |

**Balances**

**Token:** brlc
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| LP | 10100 |
| brlc | 0 |
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
| 1 | brlc | Transfer | `[LP, assetDesk, 100]` |
| 2 | LP | Withdrawal | `[100, 0]` |
| 3 | brlc | Transfer | `[surplusTreasury, assetDesk, 10]` |
| 4 | brlc | Transfer | `[assetDesk, account, 110]` |
| 5 | assetDesk | AssetRedeemed | `[account, 100, 10]` |

**Balances**

**Token:** brlc
| Holder | Balance |
| ------ | ------- |
| assetDesk | 0 |
| LP | 10000 |
| brlc | 0 |
| deployer | 0 |
| manager | 0 |
| account | 10010 |
| surplusTreasury | 9990 |
| pauser | 0 |
| stranger | 0 |



</details>

