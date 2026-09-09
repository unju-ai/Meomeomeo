# Robinhood Chain pairing — integration status

6 September 2026. Product intent: pair the Meo Meo Meo universe with a meme-stock/asset on Robinhood Chain. The exact instrument, issuer/platform, ticker, contract address and pairing mechanism remain to be confirmed. This document does not authorize or announce a launch.

## Three systems currently mean different things

| System | Evidence in repo | Relationship to the proposed pairing |
|---|---|---|
| Match gold and yarn | Server-owned game balances | Gameplay only; not equity or a chain balance |
| Champion meme-stock tape | `MemeStockService` seeds random prices, adds drift, and bumps on kills/cheers | Fictional simulation; not a market feed or executable price |
| Meo404 | Custom Solidity hybrid + Foundry test sources + hosted-handler stub | Candidate collectible experiment; no stock backing, revenue share, DEX pair or Robinhood listing implemented |

Use one shared character brand across these experiences. Do not connect simulated prices, kills, skill ratings or match rewards to real investment returns. A thematic pairing and a DEX liquidity pair are different deliverables.

## Verified network details

Robinhood's [connection documentation](https://docs.robinhood.com/chain/connecting/) lists mainnet chain ID **4663**, RPC `https://rpc.mainnet.chain.robinhood.com`, and testnet chain ID **46630**, RPC `https://rpc.testnet.chain.robinhood.com`. These are reference values checked for this integration note; no RPC transaction or deployment was performed.

Deploying on that network is separate from a Robinhood trading-app listing. Robinhood's [new Stock Tokens](https://robinhood.com/rhj/stocktokens/) are issuer-provided instruments with economic exposure to underlying securities and specific restrictions. Meo404 does not implement that product or create company ownership. If “meme stock” means an existing stock token, its exact supported contract and terms must be identified before discussing a pair.

## Architecture to settle before implementation

1. **Choose the instrument:** own meme token; custom hybrid collectible; or an external issuer's stock token. Do not silently substitute one for another.
2. **Choose the meaning of pairing:** shared brand, separate companion token, or a specific DEX pool. A pool needs verified contracts, units, transfer behavior, liquidity source and venue support.
3. **Set the collectible model:** stable chosen character vs fungible-linked NFT counts. These have different ownership experiences.
4. **Verify the integration outside gameplay:** wallet ownership, durable entitlements if applicable, chain/contract allowlists, receipt/transaction finality and recovery. No signing keys in Roblox.
5. **Publish accurate rights and status:** holder rights, metadata behavior, control powers and allocations. No claims that this is already listed, backed by stock, yielding, or approved.

The current Meo404 interface needs compatibility review before any wallet/marketplace/DEX claim: `balanceOf` counts fungible units, NFT transfer/approval/event names differ from ERC-721, and `supportsInterface` nevertheless advertises ERC-721. Its automatic NFT synchronization has no pool exemption and iterates across whole-token counts. Its metadata IDs grow as tokens move, and minting has no fixed supply cap. These are direct code observations, not an audit of the complete contract.

The bridge is also a prototype: the ledger and wallet links are in memory, ownership proof is a TODO, the TypeScript handler delegates verification and minting to injected functions, and no hosted server is started by this repo. Keep its mock status visible in technical documentation.

## Roblox boundary

The legacy README describes Robux purchase → entitlement → hosted NFT mint. Routing the mint through a separate server does not itself establish that a receipt-linked financial reward is permitted. This branch records that limitation; it does not expand or launch that flow.

Roblox's [Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards) prohibit advertising specific cryptocurrencies/NFTs and constrain financial-product advertising. Its [Community Standards](https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Community-Standards) restrict independently selling in-experience benefits through off-platform transactions. Do not interpret a shared brand as permission to add token-purchase promotion or wallet-gated game benefits. Evaluate the exact proposed implementation against current platform terms and applicable jurisdiction before production.

For this concept integration, the three new hosts discuss the game. They contain no purchase links, wallet collection, financial promises or token-holder gameplay perks. Existing prototype mint functionality remains as found and requires its own production review.
