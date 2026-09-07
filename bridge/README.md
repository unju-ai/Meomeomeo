# Meo404 claim bridge

Roblox records a **purchase entitlement**. This hosted service is what may talk to the chain.

**Do not put `MEO404_MINTER_PRIVATE_KEY` in Studio, Rojo, `Config.luau`, or this repo.** The place never signs. Legal review is required before a live Robux Developer Product.

Production SIWE must use **HTTPS** and bind `SIWE_DOMAIN` / `SIWE_URI` to the real site players see. A `meo404.local` message is for Studio / mock only.

## Roblox DataStore (`Meo404_v1`)

`src/server/Mint/EntitlementStore.luau` write-through caches these keys. ProcessReceipt and Studio `GrantProduct` / `ReplayReceipt` are idempotent on `purchaseId`.

| Key | Value |
| --- | --- |
| `ent:{purchaseId}` | `Types.Entitlement` — `purchaseId`, `userId`, `productId`, `nonce`, `createdAt`, `status` (`Granted` / `Claimed` / `Failed`), optional `wallet`, `txHash`, `claimError` |
| `user:{userId}:ents` | `{ ids: string[] }` index of that player's purchase ids |
| `user:{userId}:wallet` | `{ address, verified, verifiedAt? }` — legacy bare `0x` strings load as unverified |

Studio without API Services falls back to an in-memory cache so playtests still work. The Mint panel shows `Save: DataStore` or `Save: Memory`.

The hosted handler must **re-verify** the entitlement (Open Cloud DataStore, your DB, or a receipt you already mirrored). Do not mint from the POST body alone.

## SIWE (Sign-In With Ethereum) stub

`claim-service/siwe.ts` issues an EIP-4361-shaped message and recovers the signer with **viem** (`recoverMessageAddress`).

```
cd bridge/claim-service
npm install
npm run check:siwe   # ephemeral key, recover + one-time nonce (never commit a key)
```

| Env | Purpose |
| --- | --- |
| `SIWE_DOMAIN` | Domain printed in the message. Production: the real HTTPS host. |
| `SIWE_URI` | `URI:` field. Production: `https://<that-host>/siwe`. |
| `SIWE_CHAIN_ID` | Defaults to `1`. |
| `SIWE_ALLOW_UNVERIFIED` | `1` lets `/v1/meo404` skip the verified-wallet check (Studio / mock only). |
| `CLAIM_API_SECRET` | Bearer shared with `Nft404.ClaimApiSecret`. **Not** a chain key. |

Nonces live in process memory: **10 minute TTL**, **one-time** after a successful verify. Persist them (Redis/DB) before you run more than one instance.

### Challenge

```
POST /v1/siwe/challenge
Authorization: Bearer <Nft404.ClaimApiSecret>
```

```json
{ "robloxUserId": 123, "address": "0xabc...40 hex chars" }
```

```json
{
  "nonce": "a1b2…",
  "message": "meo404.local wants you to sign in with your Ethereum account:\n0xabc…\n…",
  "expiresAt": 1710000600,
  "domain": "meo404.local",
  "uri": "https://meo404.local/siwe"
}
```

Roblox `Nft404.ClaimApiUrl` may be the full claim path (`…/v1/meo404`). `ClaimApi.luau` strips `/v1/meo404` and calls `{root}/v1/siwe/challenge` and `{root}/v1/siwe/verify`.

### Verify

```
POST /v1/siwe/verify
Authorization: Bearer <Nft404.ClaimApiSecret>
```

```json
{ "message": "<exact challenge text>", "signature": "0x…65-byte sig" }
```

```json
{ "ok": true, "address": "0xabc…" }
```

The recovered address is recorded as SIWE-verified. Roblox stores **that** address (not the original paste) as `verified: true`.

### Studio mock vs real verify

| Mode | How to test |
| --- | --- |
| **Mock bypass (Studio)** | `Nft404.Provider = "mock"` and `AllowSiweMockBypass = true` (defaults). Link a dummy `0x`. **Claim 404** works without a signature. Or: **Challenge** → paste `studio-bypass` (or a 132-char `0x` stub) → **Verify SIWE**. |
| **Real verify** | Host this service over HTTPS. Set `SIWE_DOMAIN` / `SIWE_URI`. Point `Provider = "http"` + `ClaimApiUrl`. Player copies the challenge into an external wallet, pastes the signature. `AllowSiweMockBypass = false` and unset `SIWE_ALLOW_UNVERIFIED` before live Robux. |

The place still holds **no private keys**. Players sign in MetaMask / Rainbow / etc. Studio testers never paste a key into the experience.

`handleClaim` rejects `wallet not SIWE-verified` unless `SIWE_ALLOW_UNVERIFIED=1` or `ctx.allowUnverified`.

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

See `claim-service/handler.ts` and `claim-service/siwe.ts`. Wire `mint` to `Meo404.mintFromEntitlement(wallet, keccak256(purchaseId))` after Foundry deploy (`contracts/`). One `purchaseId` → one mint.

## Studio QA without Robux

On a Studio session with `AllowStudioMockPurchase`:

- `SimulateStudioPurchase` / `GrantProduct` writes a synthetic `studio-{userId}-{time}-{n}` entitlement (or a caller-supplied `purchaseId`).
- `ReplayReceipt(purchaseId)` re-runs the grant path. Existing rows are returned unchanged (ProcessReceipt-style retry).
- `RequestSiweChallenge` / `VerifySiwe` exercise the Mint panel. Mock bypass can skip ECDSA.

Neither grant/replay remote is available outside Studio.

## Forbidden

```
Robux receipt  →  game server signs tx  →  native/token value lands in player wallet
```

That shape is not implemented and must not be added.
