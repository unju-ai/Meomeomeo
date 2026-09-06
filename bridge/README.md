# Meo404 claim bridge

Roblox records a **purchase entitlement**. This hosted service is what may talk to the chain.

**Do not put `MEO404_MINTER_PRIVATE_KEY` in Studio, Rojo, `Config.luau`, or this repo.** The place never signs. Legal review is required before a live Robux Developer Product.

## Roblox DataStore (`Meo404_v1`)

`src/server/Mint/EntitlementStore.luau` write-through caches these keys. ProcessReceipt and Studio `GrantProduct` / `ReplayReceipt` are idempotent on `purchaseId`.

| Key | Value |
| --- | --- |
| `ent:{purchaseId}` | `Types.Entitlement` — `purchaseId`, `userId`, `productId`, `nonce`, `createdAt`, `status` (`Granted` / `Claimed` / `Failed`), optional `wallet`, `txHash`, `claimError` |
| `user:{userId}:ents` | `{ ids: string[] }` index of that player's purchase ids |
| `user:{userId}:wallet` | Linked `0x` + 40 hex address (not the zero address) |

Studio without API Services falls back to an in-memory cache so playtests still work. The Mint panel shows `Save: DataStore` or `Save: Memory`.

The hosted handler must **re-verify** the entitlement (Open Cloud DataStore, your DB, or a receipt you already mirrored). Do not mint from the POST body alone.

## Claim API contract

Roblox (`ClaimApi.luau`, `Nft404.Provider = "http"`) POSTs JSON to `Nft404.ClaimApiUrl`.

```
POST /v1/meo404
Authorization: Bearer <Nft404.ClaimApiSecret>
Content-Type: application/json
```

Request:

```json
{
  "robloxUserId": 123,
  "purchaseId": "studio-123-1710000000-1",
  "productId": 0,
  "nonce": "123-studio-123-1710000000-1",
  "wallet": "0xabc...40 hex chars"
}
```

Success (HTTP 200):

```json
{ "txHash": "0x…" }
```

Failures should be non-2xx (or 200 without `txHash`). The Roblox server marks the slip **Failed**, keeps it retryable, and surfaces the HTTP status + a short body snippet in the Mint panel. Empty URL/secret does **not** silently fall back to mock.

`Nft404.ClaimApiSecret` is a **shared Bearer secret**, not a chain key. `MEO404_MINTER_PRIVATE_KEY` lives only on this host.

See `claim-service/handler.ts` for the request shape and checks (`entitlementExists`, `alreadyMinted`, wallet regex). Wire `mint` to `Meo404.mintFromEntitlement(wallet, keccak256(purchaseId))` after Foundry deploy (`contracts/`). One `purchaseId` → one mint.

## Studio QA without Robux

On a Studio session with `AllowStudioMockPurchase`:

- `SimulateStudioPurchase` / `GrantProduct` writes a synthetic `studio-{userId}-{time}-{n}` entitlement (or a caller-supplied `purchaseId`).
- `ReplayReceipt(purchaseId)` re-runs the grant path. Existing rows are returned unchanged (ProcessReceipt-style retry).

Neither remote is available outside Studio.

## Forbidden

```
Robux receipt  →  game server signs tx  →  native/token value lands in player wallet
```

That shape is not implemented and must not be added.
