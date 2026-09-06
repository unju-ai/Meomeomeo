# Meo Meo Meo

A **cat-themed MOBA** for Roblox — every champion and NPC is a cat, lanes and nexuses are the core loop, and **voice chat is first-class**.

Players queue into a match, lock a cat champion, fight down three placeholder lanes, and try to scratch the enemy nexus to death. Teammates talk over Roblox voice (team routing when the Audio API is available). Fountain shopkeepers, a jungle coach, and a play-by-play announcer talk back through an AI chat interface that **runs on a mock provider** until you plug in a real key.

Meme stocks are a **side system**: champion tickers drift in the HUD and bump on kills. They are not the game.

**Meo404** is a lobby/meta feature: a Roblox Developer Product (Robux) grants a **claim entitlement**. A separate hosted service may later mint an ERC-404-style asset (1 whole token ↔ 1 NFT) to a linked wallet. This is **not** a Robux-to-crypto swap.

This repo is a playable **scaffold** (architecture + stubs), not a finished live-ops title.

## What’s in the scaffold

- Rojo-ready `src/` layout that syncs into Roblox Studio
- Match lifecycle: **Lobby → Champion select → In progress → Ended**
- Matchmaking stub (queue for 2+ players) plus **solo practice**
- Fourteen cat champions (original six plus Robot / Cyborg / Mystic / Wizard / Sorcerer / Warrior / Rogue / Esper archetypes) with Q / W / E / R stubs
- Lane minion waves, tower/nexus aggro, nexus gating, stub vision, Pawmart item shop
- 3-lane map placeholder: bases, towers, nexuses, river, jungle, fountain cats
- Voice module wrapping `VoiceChatService` (team access lists, safe Studio fallback)
- AI NPC talk stubs (Pawmart clerks, Old Tom, Kitty Caster) with mock + HTTP hook
- Optional yarn / meme-stock ticker on champions
- Playful HUD: lobby, draft, ability bar, voice pill, NPC chat, **Mint Meo 404** panel
- ERC-404-style Solidity collection (`contracts/`) + Foundry tests
- Purchase → entitlement → hosted claim bridge stubs (`src/server/Mint`, `bridge/`)

## Open with Rojo + Roblox Studio

1. Install [Rojo](https://rojo.space/) 7.x (`aftman install` if you use [Aftman](https://github.com/LPGhatguy/aftman) — see `aftman.toml`).
2. Install the [Rojo Studio plugin](https://www.roblox.com/library/13916111004/Rojo-7).
3. From this repo:

   ```bash
   rojo serve
   ```

4. In Studio: create a new place (or open an existing one), click the Rojo plugin, **Connect**.
5. Press Play. Use **Practice match** to walk the full loop alone.

`default.project.json` maps:

| Disk | Roblox |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` (Script) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (LocalScript) |

Place binaries (`*.rbxl`) are gitignored — source of truth is this tree.

### Playtest tips

- **Practice match** — one player, Blue team, attack Red towers/nexus to end the game.
- **Queue** — starts a real match when at least `Config.Match.MinPlayersToStart` (default 2) players are waiting.
- **Q W E R** — aim with the mouse; the server validates range, mana, cooldown, and deals damage to enemy cats, **minions**, and (if ungated) structures.
- Walk up to a blocky fountain / jungle cat and use the **Talk** prompt.
- **Practice loop for the new slice:** lock a cat → buy at the Blue fountain (**B**, or talk to Pawmart) → last-hit lane kittens → take all **3 Red towers** → Red nexus billboard flips to `(OPEN)` → smash it. Enemy towers will shoot you if you dive. Fog hides Red units until you, your minions, or a Blue tower can see them.

## How the MOBA loop works

```
Lobby  →  Queue / Practice  →  Champion select  →  Fight  →  Nexus down  →  Lobby
```

- **Server owns** gold, health, mana, cooldowns, structure HP, and match phase. Clients send intent (`UseAbility`, `SelectChampion`); they never set prices or wallets.
- **Teams:** Blue Whiskers vs Red Paws (`Teams` service). Practice puts you on Blue.
- **Champions:** data in `src/shared/ChampionCatalog.luau`. Original six — Chairman Meow, Nyan Rocket, Chonk Knight, Professor Whiskers, Scammy McMittens, Grandma Fluff — plus **Bytekit** (Robot, Mage), **Chromeclaw** (Cyborg, Bruiser), **Oracle Paws** (Mystic, Support), **Archmeow** (Wizard, Mage), **Hexkit** (Sorcerer, Mage), **Sir Scratchalot** (Warrior, Bruiser), **Shadowpounce** (Rogue, Assassin), **Mindwhisker** (Esper, Mage). Same-team duplicate locks are rejected. Draft UI scrolls.
- **Combat extras:** shield absorb and a short WalkSpeed stun stub (server-authoritative) for the new kits.
- **Map:** `src/server/World/MapBuilder.luau` builds a readable 3-lane placeholder (not final art). Structures are tagged parts; when a **nexus** hits 0 HP the other team wins.
- **Combat:** `CombatService` applies heals/dashes/AoE around the aim point. Abilities also last-hit minions and respect nexus gating.
- **Minion waves:** every ~22s both teams spawn 3 kittens per lane. They walk toward the enemy nexus, fight, and grant last-hit gold.
- **Tower AI:** living towers/nexus shoot the champion who recently hit an ally, else the nearest enemy champ, else the nearest minion.
- **Nexus gating:** a nexus is invulnerable until **all 3 towers on that team are down**. Billboard reads `(gated)` then `(OPEN)`.
- **Vision:** stub fog — enemy champs/minions are hidden unless an ally champ, minion, or tower is in radius (`VisionUpdated`).
- **Pawmart:** at your fountain (or talk to the clerk), press **B** and spend match gold on Longclaw / Yarnplate / Mana Treat / Pounce Boots. Server checks gold and location.

Tune timers and team size in `src/server/Config.luau`.

## Voice chat

Voice is a first-class feature. The module lives in `src/server/Voice/VoiceService.luau`.

**Default mode is team voice:** teammates hear each other; enemies do not. That uses Roblox’s Audio API (`AudioDeviceInput` + `SetUserIdAccessList`) as documented in [Voice Chat](https://create.roblox.com/docs/chat/voice-chat). If those APIs fail (typical in Solo Play), the module **stubs cleanly**, keeps the match running, and the HUD explains why.

Proximity (spatial) voice is the engine default and the fallback when team lists are unavailable (`Config.Voice.FallbackToProximity`).

### Enable it in Studio / on the live place

Scripts cannot flip the experience-level voice permission. You must:

1. Open the synced place in Studio.
2. **File → Experience Settings → Communication**.
3. Turn on **Enable Voice Chat** (formerly “Enable Microphone”).
4. Keep **maximum players ≤ 100** (Creator Dashboard → Place → Access). This project is designed as a 5v5 (10).
5. Optional: **Show Services… → VoiceChatService**. This repo already declares that service in `default.project.json` with:
   - `EnableDefaultVoice = true` (default spatial emitters on characters)
   - `UseAudioApi = Enabled` (so team routing can parent `AudioDeviceInput`)
6. **Publish** the place. Voice does not fully work in unpublished Solo Play.
7. Test with **Team Test** (or two published clients). Eligible testers must be **age-verified 13+** with voice opted in on their account.
8. Optional: Communication → **Chat & Voice Groups APIs** if you later use `GetChatGroupsAsync` for matchmaking across servers.

If Studio blocks voice, the HUD shows `StudioBlocked` / `Unavailable` and players can still play. That is expected.

`Config.Voice.Mode` is `"Team"` or `"Proximity"`.

## Talking AI cats

NPCs (shopkeepers, coach, announcer) share one interface:

```
player message → AiChatService → Provider.complete(message, context) → reply
```

- **`mock` (default):** personality lines that mention the player, champion, and score. No network, no key.
- **`http`:** `src/server/Npcs/HttpAiProvider.luau` POSTs a Chat Completions-shaped body to `Config.Ai.Endpoint` with `Authorization: Bearer <ApiKey>`. Empty key or failed HTTP **falls back to mock**.

Set placeholders only in `src/server/Config.luau`:

```lua
Ai = {
  Provider = "mock", -- or "http"
  Endpoint = "",     -- e.g. https://api.openai.com/v1/chat/completions
  ApiKey = "",       -- NEVER commit a real key
  Model = "gpt-4o-mini",
}
```

Also enable **Game Settings → Security → Allow HTTP Requests** before using `http`. See `.env.example` for a reminder of the same fields (Roblox cannot read `.env` at runtime).

Kitty Caster also broadcasts match events (`AnnouncerMessage`) without an LLM.

## Meo404 (Robux product → entitlement → hosted mint)

### Compliance caveat (read this)

Roblox Terms restrict exchanging Robux for real-world crypto or cash-like value.

**This scaffold does not send crypto because someone spent Robux.** There is no `wallet.transfer`, no “paste your address and we airdrop from the game server,” and no in-experience swap UI.

What it *does* model:

1. Player buys a **Roblox Developer Product** (Robux). Roblox owns that purchase.
2. `MarketplaceService.ProcessReceipt` on the **Roblox server** marks the receipt fulfilled and writes a **claim entitlement** (`userId` + `productId` + `PurchaseId` nonce) into `EntitlementStore` (in-memory stub; TODO DataStore or external API).
3. The player **links a wallet** (format check only; SIWE is a later hosted step).
4. A **separate claim service** (not Roblox) verifies the entitlement and calls `Meo404.mintFromEntitlement`. One purchase → one mint (idempotent on `PurchaseId` / `bytes32` entitlement id).

**Legal / compliance review is required before production.** Never put a chain private key in the Roblox place, Rojo tree, or `Config.luau`. Signing and minting belong on a hosted backend.

### Architecture

```
Player                 Roblox game server              Hosted claim API              Chain
  |                            |                              |                       |
  |  Buy Developer Product     |                              |                       |
  |  (Robux, not crypto)       |                              |                       |
  |--------------------------->|                              |                       |
  |                            | ProcessReceipt               |                       |
  |                            | grant entitlement            |                       |
  |                            | (PurchaseId + nonce)         |                       |
  |  Link 0x wallet (stub)     |                              |                       |
  |--------------------------->|                              |                       |
  |  Claim                     | POST /v1/meo404              |                       |
  |--------------------------->|----------------------------->| mintFromEntitlement   |
  |                            |                              |---------------------->|
  |                            |                              |  1e18 token + 1 NFT   |
```

Forbidden shape (not implemented, do not add):

```
Robux receipt  →  game server signs tx  →  native/token value lands in player wallet
```

### Enable steps

**Roblox**

1. Creator Dashboard → Monetization → **Developer Products** → create “Mint Meo 404”.
2. Put the numeric id in `src/server/Config.luau` → `Nft404.DeveloperProductId`.
3. Publish. `ProcessReceipt` only runs on a live/published purchase path; Studio uses the mock grant when `AllowStudioMockPurchase` is true and the id is still `0`.
4. Play → lobby → **Mint Meo 404** → (Studio) grant entitlement → link a dummy `0x` address → **Claim 404**. Mock mode writes a fake `0xMOCK…` tx hash.
5. For a real prompt, set a non-zero product id; the client calls `MarketplaceService:PromptProductPurchase`.

**Chain (Foundry)**

```bash
cd contracts
forge install foundry-rs/forge-std
forge test -vv
# keys stay in the environment — see .env.example
forge script script/Deploy.s.sol --rpc-url $MEO404_RPC_URL --broadcast
```

Point `Nft404.Provider = "http"` and `ClaimApiUrl` at your hosted handler (`bridge/claim-service/handler.ts`). The backend secret is `ClaimApiSecret` (shared auth), **not** the minter private key.

### Pairing rule

Classic 404: **1 whole token (1e18) ↔ 1 NFT**. Transfers across that boundary mint or burn NFTs. `mintFromEntitlement` is minter-only and rejects reused ids. Details in `contracts/README.md`.

## Meme stocks (side system)

`src/server/Economy/MemeStockService.luau` keeps server-authored champion tickers and a **yarn** wallet. Prices wander; kills bump the killer’s cat. The top HUD tape is cosmetic for now (`CheerTicker` remote exists for later shop/wager UI). Turn it off with `Config.Economy.Enabled = false`.

## Project layout

```
src/shared/          Types, remotes, constants, champion catalog, item catalog
src/server/
  init.server.luau   Wires remotes + services
  Config.luau        Tunables + AI / Meo404 product placeholders
  Match/             Matchmaking, match lifecycle, combat, minions, towers, vision, shop
  Voice/             VoiceChatService wrapper
  World/             3-lane map + cat NPC placeholders
  Npcs/              Catalog, mock/http AI, chat service
  Economy/           Optional meme stocks
  Mint/              ProcessReceipt, entitlements, claim API stub
src/client/          HUD, lobby, mint panel, draft, abilities, voice, NPC chat
contracts/           Meo404.sol + Foundry tests
bridge/              Hosted claim-handler stub
```

Authority rule: money, prices, damage, match state, and purchase entitlements live on the server. Chain keys never do.

## Next suggested steps

1. Real cat meshes / animations and a proper camera/minimap.
2. Champion auto-attack, last-hit assist gold, and inner/inhibitor towers.
3. Brush / true fog of war (server-authoritative visibility, not just LocalTransparency).
4. Reserved-server matchmaking + teleport; optional `GetChatGroupsAsync` so voice-compatible players land together.
5. Custom voice: push-to-talk, party chat in lobby, per-player mute UI.
6. Swap the HTTP stub for a hosted proxy so API keys never sit in the place file.
7. DataStores for cosmetics funded by yarn / meme-stock wagers.
8. Persist Meo404 entitlements (DataStore or Open Cloud); SIWE wallet proof on the claim API.
9. Compliance review before any live Developer Product that mentions 404 / NFTs.

## License / secrets

Do not commit API keys, minter keys, `.env`, or `Secrets.luau`. `.gitignore` already drops Roblox binaries, Rojo sourcemaps, Foundry `out/` + `lib/`, and secret files.
