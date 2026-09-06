# Meo404 contracts

ERC-404-style collection for Meo Meo Meo: **1 whole token (1e18) ↔ 1 NFT**.

Minting is locked to a **minter role**. The minter is a hosted claim service that has already verified a Roblox `ProcessReceipt` entitlement. The Roblox game never holds a chain private key and never sends crypto because a player spent Robux.

## Pairing rule

| Fungible balance | NFTs owned |
| --- | --- |
| `floor(balance / 1e18)` | that many ERC-721s |
| Transfer 1.0 token | sender loses 1 NFT, recipient gains 1 NFT |
| Transfer 0.4 token from 1.0 | sender drops below 1.0 → NFT burns; recipient has 0.4 → no NFT |
| `transferFromNFT` | moves that token id **and** exactly 1e18 units |

`mintFromEntitlement(to, entitlementId)` is idempotent: the same `bytes32` cannot mint twice. The backend should pass `keccak256(purchaseId)` (or another unique receipt id).

## Tooling (Foundry)

From this folder, with [Foundry](https://book.getfoundry.sh/getting-started/installation) on your PATH:

```bash
forge install foundry-rs/forge-std
forge test -vv
forge fmt
```

`forge test` in this repo: **8 passed** (minter auth, idempotent entitlement, 1 token ↔ 1 NFT, fractional burn/combine, NFT transfer).

Deploy (keys stay in the shell environment, never in git or Roblox):

```bash
export MEO404_DEPLOYER_PRIVATE_KEY=0x...
export MEO404_RPC_URL=https://...
export MEO404_MINTER=0x...   # claim-service hot wallet
forge script script/Deploy.s.sol --rpc-url $MEO404_RPC_URL --broadcast
```

## Files

- `src/Meo404.sol` — token + NFT + minter + entitlement replay protection
- `test/Meo404.t.sol` — mint auth, 1:1 pairing, fractional burn, NFT transfer
- `script/Deploy.s.sol` — env-based deploy
