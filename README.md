# Meo Meo Meo

A **cat-themed MOBA** for Roblox — every champion and NPC is a cat, lanes and nexuses are the core loop, and **voice chat is first-class**.

Players queue into a match, lock a cat champion, fight down three placeholder lanes, and try to scratch the enemy nexus to death. Teammates talk over Roblox voice (team routing when the Audio API is available). Fountain shopkeepers, a jungle coach, and a play-by-play announcer talk back through an AI chat interface that **runs on a mock provider** until you plug in a real key.

Meme stocks are a **side system**: champion tickers drift in the HUD and bump on kills. They are not the game.

**Meo404** is a lobby/meta feature: a Roblox Developer Product (Robux) grants a **claim entitlement**. A separate hosted service may later mint an ERC-404-style asset (1 whole token ↔ 1 NFT) to a linked wallet. This is **not** a Robux-to-crypto swap.

This repo is a playable **scaffold** (architecture + stubs), not a finished live-ops title.

**Want to run it today?** Follow **[PLAYTEST.md](PLAYTEST.md)** (Rojo → Practice → keybinds → Meo404 Studio mock → publish checklist). In Play, click **?** or hold **H**.

## What’s in the scaffold

- Rojo-ready `src/` layout that syncs into Roblox Studio
- Match lifecycle: **Lobby → Champion select → In progress → Ended**
- Matchmaking stub (queue for 2+ players) plus **solo practice**
- Fourteen cat champions (original six plus Robot / Cyborg / Mystic / Wizard / Sorcerer / Warrior / Rogue / Esper archetypes) with Q / W / E / R stubs and **distinct Part silhouettes** (no mesh binaries)
- Lane minion waves, tower/nexus aggro, nexus gating, stub vision, Pawmart item shop
- Champion auto-attack, assist gold, levels 1–18, death timers, kill feed, jungle camps, scoreboard, fountain regen, minimap
- **Recall (F)** to fountain (channel circle under feet), **match end screen** (victory/defeat, team KDA, MVP), clean return to lobby
- Trinket wards (**4**), Pawmart **Whisker Lens** (**5**), line skillshots / dash indicators, destroyable enemy wards
- Hold **G** smart pings (team-only wheel + minimap Attention); visible tower/champ names in the line
- 3-lane map placeholder: bases, towers, nexuses, river, jungle, fountain cats
- Voice module wrapping `VoiceChatService` (team access lists, safe Studio fallback)
- AI NPC talk stubs (Pawmart clerks, Old Tom, Kitty Caster) with mock + HTTP hook
- Optional yarn / meme-stock ticker on champions
- Playful HUD: lobby, draft, ability bar, kill feed, **Tab scoreboard**, minimap, voice pill, NPC chat, **Mint Meo 404** panel, **Audio** (SFX + Music) sliders, hold **T** emote wheel, **?** / hold **H** help, first-Practice **tip cards**
- Lightweight client SFX + phase music beds (crossfade) + screen juice (hit flash, level-up pop, tower/nexus shake)
- Combat VFX stubs: ability beams/rings, AA claw + hit spark (debounced), tower bolts, structure death puffs, shield bubble, stun stars, recall circle
- ERC-404-style Solidity collection (`contracts/`) + Foundry tests
- Purchase → entitlement → hosted claim bridge stubs (`src/server/Mint`, `bridge/`)

## Open with Rojo + Roblox Studio

Full walkthrough (Practice vs Queue, Meo404 API Services, publish ids): **[PLAYTEST.md](PLAYTEST.md)**.

1. Install [Rojo](https://rojo.space/) 7.x (`aftman install` if you use [Aftman](https://github.com/LPGhatguy/aftman) — `aftman.toml` pins **Rojo 7.4.4**; keep the Studio plugin on the same 7.x line).
2. Install the [Rojo Studio plugin](https://www.roblox.com/library/13916111004/Rojo-7).
3. From this repo:

   ```bash
   rojo serve
   ```

4. In Studio: create a new place (or open an existing one), click the Rojo plugin, **Connect**.
5. Press Play. Use **Practice match** to walk the full loop alone. **?** or hold **H** lists keybinds.

`default.project.json` maps:

| Disk | Roblox |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` (Script) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (LocalScript) |

Place binaries (`*.rbxl`) are gitignored — source of truth is this tree.

### Playtest tips

- **Practice match** — one player on Blue vs **3 AI cats** on Red (top / mid / bot). Lobby toggle **Easy / Normal / Hard**. Attack bots, towers, then the nexus.
- **Queue** — lobby shows count / ETA / match-found. Default `MinPlayersToStart = 2` (set **6** or **10** for a real pop). With `MatchPlaceId = 0` the match starts **in this server**. Reserved servers need a published experience (see below).
- **LMB** — lock a basic attack on an enemy kitten, champion, or structure. The server checks range, cadence, item damage, and vision (you cannot AA a fogged target). Confirmed swings show a claw flash + debounced hit spark. **X then click** is attack-move (walk + auto-acquire). **S** stops. **A** stays as strafe.
- **Q W E R** — aim with the mouse; the server validates range, mana, cooldown, and deals damage to enemy cats, **minions**, wards, and (if ungated) structures. **Hold** a line skillshot or dash (Professor / Bytekit / Nyan Q, Shadowpounce W, and any dash) to see a range + path indicator; **release** to fire (beam / ring / streak on confirm). Instant/self and ground AoEs still fire on press.
- **4** — trinket ward (free, 70s cooldown, 60s duration, one live). Team-only vision bubble. Placing another replaces yours.
- **5** — Whisker Lens sweep (buy at Pawmart). Reveals and damages enemy wards in a short radius.
- **Tab** (hold) — scoreboard: KDA, CS, gold, level, items, team totals.
- **V** — toggle a simple locked follow camera (north-up, overhead).
- **B** — Pawmart (fountain only). **Not recall.**
- **F** — recall: 7s channel, server teleports you to your fountain. **Damage, movement, attacks, abilities, or S / F again cancel it.**
- **Minimap** (bottom-right) — lanes, towers, nexuses, allies, visible enemies/minions, and visible jungle camps (amber). Click it to ping teammates.
- **Audio** (top-right, under voice) — SFX and Music sliders / mute, independent. Sounds and beds are placeholders (`rbxasset://sounds/…`); swap ids in `SoundIds.luau` / `MusicIds.luau`.
- **?** or hold **H** — in-game control sheet (same list as PLAYTEST.md). First Practice also shows a non-modal tip card (Next / Skip all). Lobby **Show tips** replays; dismiss persists on `MeoTutorialDone` / DataStore `MeoTutorial_v1` (memory fallback in Studio).
- Walk up to a blocky fountain / jungle cat and use the **Talk** prompt.
- **Practice loop:** first Practice shows a **non-modal tip card** (Next / Skip all; lobby **Show tips** replays). Lock **Professor Whiskers** (or Bytekit / Nyan Rocket) → confirm silhouettes + nameplates → walk a gold-dotted lane and fight a bot + wave → hold **Q**, release to fire → **4** ward → **B** at fountain → **F** recall → Tab → 3 Red towers until `(OPEN)` → smash nexus. Two-player queue also pads empty slots with bots up to 3 per side.

## How the MOBA loop works

```
Lobby  →  Queue / Practice  →  Champion select  →  Fight  →  Nexus down  →  End screen  →  Lobby
```

- **Server owns** gold, health, mana, XP, levels, death timers, auto-attacks, recall teleports, wards, vision, structure HP, and match phase. Clients send intent (`UseAbility`, `IssueAttack`, `PlaceWard`, `UseLens`, `StartRecall`, `SelectChampion`); they never set prices or wallets.
- **Teams:** Blue Whiskers vs Red Paws (`Teams` service). Practice puts you on Blue and fills Red with practice bots.
- **Practice bots:** `BotService` spawns dummy champion models (negative `userId`, name suffix `(Bot)`). Combat is the same server path as players (`issueAttackFor` / `useAbilityFor`). **Easy** thinks slowly, retreats early (~42% HP), AAs anything, no lead/dodge/dive IQ, buys Longclaw + Yarnplate, 0.88× damage, and will not walk under enemy towers. **Normal** last-hits, leads line shots, sidesteps incoming line/ground casts, dives only with a crashing wave or a short low-HP chase, mid can take a nearby camp. **Hard** is faster, 1.22× damage, tighter CS, fuller build (incl. Whisker Lens), one early ward, dives to finish a kill, and uses lens when an enemy ward is revealed nearby. Queue matches fill each side to `Config.Bots.QueueFillTo` when `Match.PadQueueWithBots` is on (uses the last practice difficulty). Practice is always **in-place** (never teleports).
- **Queue / reserved servers:** `MatchmakingService` + `MatchTeleport`. Enough humans (or max-wait + bots) either start draft here or `ReserveServer(MatchPlaceId)` and teleport with seat/team data. The reserved instance reads `GetJoinData().TeleportData` and boots champion select. Failures (Studio, unpublished, bad PlaceId) **fall back in-place**. Party invite stub: add another player in this lobby server.
- **Champions:** data in `src/shared/ChampionCatalog.luau`. Original six — Chairman Meow, Nyan Rocket, Chonk Knight, Professor Whiskers, Scammy McMittens, Grandma Fluff — plus **Bytekit** (Robot, Mage), **Chromeclaw** (Cyborg, Bruiser), **Oracle Paws** (Mystic, Support), **Archmeow** (Wizard, Mage), **Hexkit** (Sorcerer, Mage), **Sir Scratchalot** (Warrior, Bruiser), **Shadowpounce** (Rogue, Assassin), **Mindwhisker** (Esper, Mage). Same-team duplicate locks are rejected. Draft UI scrolls. Locked cats get a **readable silhouette** (see below).
- **Combat extras:** shield absorb and a short WalkSpeed stun stub (server-authoritative) for the new kits.
- **Map:** `src/server/World/MapBuilder.luau` builds a 3-lane rift with a night-market art pass (lane dots, indigo river, fountain kits, tower ears / yarn, jungle camp pedestals, soft brush). Same `MapBounds` / lane Z as the minimap. Structures are tagged parts; when a **nexus** hits 0 HP the other team wins.
- **Combat:** `CombatService` applies heals, **direction dashes** (clamped to range), **line skillshots**, and ground AoE. `Shared.Targeting` picks the mode. **Auto-attacks** tick on the server (range, windup, interval, AD from items). Abilities and AAs last-hit minions/wards and respect nexus gating + vision.
- **Assists:** if an ally damaged a champion within 8s of the kill, they get assist gold/XP (`AssistGold = 60`, kill bounty stays `180`). Minion last-hits stay last-hit only.
- **Levels 1–18:** shared `Progression.luau`. XP to next level = `40 + (level-1)*28`. Last-hits (`18` XP), nearby minion deaths (`10` XP in 42 studs), kills (`80`), assists (`30`). On level-up: +72 HP, +28 mana, +3 AD, +4 AP. **Ranks auto-assign** (Q then W then E, max 5). **R unlocks at 6**, ranks again at 11 and 16. No + buttons.
- **Death:** soft-death (character stays, combat drops). Respawn = `6 + (level-1)*0.55` seconds at your fountain with full HP/mana. HUD shows the timer. Kill/assist gold unchanged.
- **Kill feed:** top-of-screen cat copy for kills, towers, nexus, and level-ups (`KillFeed`).
- **Minion waves:** every ~22s both teams spawn 3 kittens per lane. They walk toward the enemy nexus, fight, and grant last-hit gold.
- **Tower AI:** living towers/nexus shoot the champion who recently hit an ally, else the nearest enemy champ, else the nearest minion.
- **Nexus gating:** a nexus is invulnerable until **all 3 towers on that team are down**. Billboard reads `(gated)` then `(OPEN)`.
- **Vision:** stub fog — enemy champs/minions/jungle are hidden unless an ally champ, minion, tower, or **ward** is in radius (`VisionUpdated`).
- **Trinket ward (4):** free. Server places a team-colored totem (`WardService`) that feeds `VisionService` for 60s. One per player; 70s cooldown. Not shop — **B stays Pawmart**.
- **Whisker Lens (Pawmart, 180g):** unique. **5** reveals enemy wards in 32 studs for 5s and deals 80 damage to them (wards have 60 HP — one sweep or ~3 AAs). Enemy wards are stealthed unless revealed or you stand within 14 studs.
- **Pawmart:** at your fountain (or talk to the clerk), press **B** and spend match gold on Longclaw / Yarnplate / Mana Treat / Pounce Boots / **Whisker Lens**. Server checks gold and location. Longclaw raises AA damage. **B is shop only — recall is F, ward is 4.**
- **Recall:** press **F** (not B). Server starts a 7s channel (`Config.Combat.RecallSeconds`), roots you, then `PivotTo` your fountain. Interrupted by champion/minion/tower/jungle damage, movement > 2.5 studs, AA, attack-move, abilities, **S**, or **F** again. Fountain regen still ticks while you channel.
- **Fountain regen:** alive + inside fountain radius → `48` HP and `56` mana per second (server tick). Out in lane it's the slow combat regen.
- **Jungle:** six neutral camps (Yarn Golems, Pigeon Packs, River Crabs). Aggro when hit, leash back if you run, last-hit gold/XP/CS, nearby allies get a little XP, then respawn. Fog applies. `JungleService`.
- **Scoreboard:** hold Tab. Client overlay on the match snapshot (includes `cs`).
- **Match end:** nexus HP → 0 stops minion/jungle/tower/vision ticks, clears combat (including recall/death timers), and shows Victory/Defeat + team KDA + MVP. **Ended counts as busy** so queue/practice cannot start underneath the screen. **Back to lobby** (`LeaveMatch`) or **Practice again** (`PlayAgain`) skip the 45s timer; the timer still auto-returns so nobody soft-locks. Kitty Caster + kill-feed announce “Enemy nexus destroyed!” (per-team Victory/Defeat).
- **Minimap:** client reads match + vision frames; click-to-ping is team-only (`PingReceived`).
- **Camera:** optional locked follow (`V`). Does not change WASD. Disabled on the end screen and in lobby.

Tune timers and team size in `src/server/Config.luau`.

## Production config (placeholders)

`0` / `""` is Studio-safe. Fill **locally** before a live place. Never commit secrets. Same list is commented at the top of `src/server/Config.luau`.

| Field | Default | Production |
| --- | --- | --- |
| `Match.MatchPlaceId` | `0` | Published PlaceId for `ReserveServer` (this lobby or a dedicated match place). `0` = start in this server. |
| `Match.LobbyPlaceId` | `0` | Published lobby PlaceId for reserved-server “Back to lobby”. `0` = remember the place they queued from. |
| `Match.MinPlayersToStart` | `2` | `6` (3v3) or `10` (5v5) for a real pop. |
| `Nft404.DeveloperProductId` | `0` | Creator Dashboard Developer Product id. `0` = Studio **GrantProduct** mock only. |
| `Nft404.ClaimApiUrl` | `""` | Hosted `POST /v1/meo404`. Keep `Provider = "mock"` until the bridge is live. |
| `Nft404.ClaimApiSecret` | `""` | Shared Bearer secret with the bridge. **Not** a chain key. Never commit. |
| `Ai.Endpoint` / `Ai.ApiKey` | `""` | Only if `Ai.Provider = "http"`. Never commit a real key. |

Steps to wire PlaceIds and the Developer Product: [PLAYTEST.md](PLAYTEST.md) §§6–7.

## Reserved-server matchmaking

Queue is reserved-server-ready. **Practice never teleports.**

| Config (`Match`) | Default | Meaning |
|---|---|---|
| `MinPlayersToStart` | `2` | Humans needed to form. Use `6` (3v3) or `10` (5v5) live. |
| `MatchPlaceId` | `0` | `0` = start the match **in this server**. Set a published PlaceId to reserve a private instance (same place or a dedicated match place). |
| `LobbyPlaceId` | `0` | Where reserved-server “Back to lobby” sends people. `0` = remember the PlaceId they queued from. |
| `MaxWaitSeconds` | `90` | If `PadQueueWithBots`, form with whoever is waiting after this. |
| `PadQueueWithBots` | `true` | Fill empty roster slots (`Config.Bots.QueueFillTo`). |
| `ArrivalTimeoutSeconds` | `20` | Reserved instance starts draft when seats arrive, or this timeout. |

**Wire `MatchPlaceId`**

1. Publish the experience (reserved servers do **not** work in unpublished Studio).
2. Creator Dashboard → the lobby place and/or a dedicated match place. Copy the numeric PlaceId.
3. Set `Config.Match.MatchPlaceId` to that id (can be this lobby’s PlaceId for a same-place reserved instance, or a second place that also has this Rojo tree).
4. Optional: set `LobbyPlaceId` to the public lobby place so post-match teleport is explicit.
5. Publish again. Queue with 2+ clients; you should see **MATCH FOUND** then a teleport.

**Studio limits**

- `ReserveServer` / `TeleportAsync` to reserved instances require a **published** experience and live clients.
- In Studio (or if reserve/teleport throws), the server logs a warning and **starts the match in-place** — same draft/fight/bots/end screen as before.
- Two Studio players can still test queue UX (count, ETA, cancel, party invite, match-found) and the in-place fallback.

**Match place bootstrap**

Teleport payload (`MeoMatch`) carries `matchId`, `lobbyPlaceId`, teams, optional pre-locks, and `padWithBots`. A reserved server (`PrivateServerId` set, `PrivateServerOwnerId == 0`) waits for those userIds, then `MatchService.start(..., seats, { reserved = true })`. Draft still happens in the match instance unless seats already have `championId`.

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
2. `MarketplaceService.ProcessReceipt` on the **Roblox server** marks the receipt fulfilled and writes a **claim entitlement** (`userId` + `productId` + `PurchaseId` nonce) into `EntitlementStore`. Writes go to DataStore `Meo404_v1` when API Services are on; Studio without access falls back to an in-memory cache. Grant is **idempotent by `PurchaseId`**.
3. The player **links a wallet** (`0x` + 40 hex, not the zero address). Paste alone is **unverified**. They request a SIWE challenge, sign in an external wallet (or `studio-bypass` in Studio), and the server stores the **recovered** address as verified.
4. A **separate claim service** (not Roblox) rejects unverified wallets (unless a Studio mock-bypass flag), re-checks the entitlement, and calls `Meo404.mintFromEntitlement`. One purchase → one mint (idempotent on `PurchaseId` / `bytes32` entitlement id). Failed claims stay retryable; already-claimed returns success.

**Legal / compliance review is required before a live Robux product.** Never put a chain private key in the Roblox place, Rojo tree, or `Config.luau`. Signing and minting belong on a hosted backend. See `bridge/README.md` for DataStore keys and the claim HTTP contract.

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
  |  Link 0x (unverified)      |                              |                       |
  |--------------------------->|                              |                       |
  |  SIWE challenge / verify   | POST /v1/siwe/*              | recover signer        |
  |--------------------------->|----------------------------->|                       |
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
3. Publish. `ProcessReceipt` only runs on a live/published purchase path; Studio uses `GrantProduct` / `SimulateStudioPurchase` when `AllowStudioMockPurchase` is true (product id may still be `0`). `ReplayReceipt` re-runs grant for the same `PurchaseId` without extra Robux.
4. Play → lobby → **Mint Meo 404**. The panel shows **Save: DataStore | Memory**, linked vs **SIWE-verified** wallet, and each slip as **Pending claim** / **Failed — retry** / **Claimed**. Link a dummy `0x` → **Challenge** → sign externally or paste `studio-bypass` → **Verify SIWE**. With `AllowSiweMockBypass` (Studio default) **Claim 404** still works without verify. Mock mode writes a fake `0xMOCK…` tx hash. Set `AllowSiweMockBypass = false` before live Robux.
5. For a real prompt, set a non-zero product id; the client calls `MarketplaceService:PromptProductPurchase`.
6. Enable **Game Settings → Security → Enable Studio Access to API Services** if you want entitlements and wallets to survive a Studio stop. Without it, the store stays in memory for that session.

### DataStore keys (`Meo404_v1`)

| Key | Value |
| --- | --- |
| `ent:{purchaseId}` | Entitlement row (status, nonce, wallet, txHash, claimError) |
| `user:{userId}:ents` | `{ ids = { purchaseId, ... } }` |
| `user:{userId}:wallet` | `{ address, verified, verifiedAt? }` (legacy string = unverified) |

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

## Audio & juice (client)

All gameplay SFX are **client-only**. They do not change combat, queue, bots, or Meo404 DataStores.

Cues live in `src/client/Audio/SoundIds.luau`. Defaults are Roblox engine builtins so the repo stays free of `.ogg` / `.mp3` binaries:

| Cue | Hook | Default `SoundId` |
| --- | --- | --- |
| `AutoHit` | Successful AA lock / swing (`IssueAttack`, `CombatUpdated` cadence). Debounced 140ms. | `rbxasset://sounds/hit.wav` |
| `AbilityCast` | `UseAbility` / Whisker Lens | `rbxasset://sounds/swoosh.wav` |
| `LevelUp` | Kill feed `level` + combat level edge | `rbxasset://sounds/electronicpingshort.wav` |
| `Kill` | Kill feed `kill` | `rbxasset://sounds/snap.wav` |
| `TowerDown` | Kill feed `tower` + subtle camera shake | `rbxasset://sounds/collision.wav` |
| `NexusDown` | Kill feed `nexus` + slightly stronger shake | `rbxasset://sounds/collision.wav` |
| `RecallLoop` | `CombatState.recalling` (loop until cancel/finish) | `rbxasset://sounds/action_get_up.mp3` |
| `ShopBuy` | Pawmart buy success | `rbxasset://sounds/switch.wav` |
| `WardPlace` | Trinket **4** success | `rbxasset://sounds/button.wav` |
| `MatchFound` | `QueueUpdated.phase == "Found"` (+ Victory stinger) | `rbxasset://sounds/electronicpingshort.wav` |
| `Announcer` | Kitty Caster lines that are not already a feed cue | `rbxasset://sounds/electronicpingshort.wav` |
| `Heal` | Local HP jump on `CombatUpdated` | `rbxasset://sounds/electronicpingshort.wav` |

**Swap for real assets:** upload to Creator Store → copy the numeric id → set `id = "rbxassetid://YOUR_ID"` on that cue. Tweak `volume` / `playbackSpeed` in the same table. Mute and master volume go through `SoundService.MeoSfx` (`SoundGroup`). Session slider values sit on the local player as `MeoSfxVolume` / `MeoSfxMuted`.

### Music beds

`src/client/Audio/Music.luau` loops a quiet bed per match phase and **crossfades ~1s** (no hard cuts). Default Music master is **0.35** (SFX is 0.8). Group: `SoundService.MeoMusic`. Slider: `MeoMusicVolume` / `MeoMusicMuted`.

| Bed | Phase | Placeholder | Mood knob |
| --- | --- | --- | --- |
| `Lobby` | Lobby | `rbxasset://sounds/action_get_up.mp3` @ 0.52 | Cozy / slow |
| `ChampionSelect` | Champion select | same file @ 0.82 | Anticipation |
| `InProgress` | Match | same file @ 1.08 | Low underscore |
| `Ended` | End screen | same file @ 0.40 | Wind-down |

Those four `id`s are **placeholders** (one engine loop, four speeds). Replace each `MusicIds` row with a real looped `rbxassetid://…` and keep `volume` low so SFX / emotes stay on top. MatchFound and nexus kill-feed stingers **duck** the bed briefly (`Music.duck`).

Emote SFX still use `MeoSfx` — music mute does not silence them.

Screen juice (`src/client/Juice/ScreenJuice.luau`): coral damage flash, mint heal flash, `LEVEL n!` pop, `CameraFollow.shake` on tower/nexus.

## Champion looks (placeholders)

Each locked cat gets a **distinct silhouette** built from engine `Part`s — body tint, ears, tail, team collar, plus archetype flair (antenna / visor / hat / hood / cape / blades / aura). No mesh binaries in git.

| File | Role |
| --- | --- |
| `src/shared/ChampionLooks.luau` | Colors, materials, flair flags per champion id |
| `src/server/World/ChampionAppearance.luau` | Welds extras onto the character / bot dummy; nameplate; idle ear/tail twitch |

Rules the builder keeps:

- **`HumanoidRootPart` stays the primary combat box.** Bots keep the existing `2 × 2 × 1` root (it goes transparent; the torso/head/flair are visual only). Player avatars are not resized.
- Extra parts are `Massless`, `CanCollide = false`, parented under a `MeoAppearance` folder.
- Nameplates are a `BillboardGui`: champion name + role; bots keep `(Bot)`. Role text uses the team color.
- Minimap pips stay **team colors** (local cream / Blue / Red). Champ body tints do not recode the map.
- A light team wash (~18%) tints the body so sides stay readable while champs stay distinct.

**Swap for real meshes later:** upload a cat mesh or accessories to the Creator Store, then replace the Part recipes inside `ChampionAppearance` (or hang `SpecialMesh` / `MeshPart` instances with `rbxassetid://` on the same welds). Keep `HumanoidRootPart` as `PrimaryPart` and do not grow it to match a fancy mesh — combat range, dash `PivotTo`, and recall all use that box. Nameplates can stay on the root. Draft card swatches read `ChampionLooks` and do not need the 3D mesh.

## Combat VFX (placeholders)

Confirmed hits and casts broadcast on the `CombatFx` remote (`src/server/World/FxRelay.luau`). The client pools short-lived Parts / Beams / one-shot `ParticleEmitter`s in `src/client/Juice/CombatFx.luau` — no mesh binaries.

| Cue | What you see |
| --- | --- |
| Line skillshot | Brief neon beam + impact burst |
| Ground / instant AoE | Expanding ring |
| Dash | Streak along the path |
| Heal / shield | Soft burst; shield also gets a ForceField bubble (~1.1s) |
| Auto-attack | Claw flash + hit spark (spark debounced ~140ms) |
| Tower / nexus shot | Team-colored bolt |
| Structure death | Puff of neon balls |
| Stun | Three stars orbit the head for the stun duration |
| Recall | Mint cylinder under feet for the 7s channel |

Aim indicators (`TargetingIndicator`) stay client-predicted while you hold Q/W/E/R. World FX spawn only after the server confirms the cast or hit. Combat numbers are unchanged.

## Meme stocks (side system)

`src/server/Economy/MemeStockService.luau` keeps server-authored champion tickers and a **yarn** wallet. Prices wander; kills bump the killer’s cat. The top HUD tape is cosmetic for now (`CheerTicker` remote exists for later shop/wager UI). Turn it off with `Config.Economy.Enabled = false`.

## Project layout

```
PLAYTEST.md          Studio / publish walkthrough + keybind sheet
src/shared/          Types, remotes, constants, champion catalog, champion looks, item catalog, progression, targeting, emote catalog, ping catalog
src/server/
  init.server.luau   Wires remotes + services
  Config.luau        Tunables + AI / Meo404 product placeholders
  Match/             Matchmaking, reserved-server teleport, match lifecycle, combat, minions, jungle, towers, vision, wards, shop, practice bots
  Voice/             VoiceChatService wrapper
  World/             3-lane map (art pass + lighting), cat NPC placeholders, champion appearance builder, FX relay
  Npcs/              Catalog, mock/http AI, chat service
  Economy/           Optional meme stocks
  Mint/              ProcessReceipt, DataStore entitlements, SIWE challenge/verify, claim API stub, Studio GrantProduct/ReplayReceipt
  Tutorial/          First-Practice tip dismiss flag (DataStore + memory fallback)
  Social/            Emote cooldown + nearby replicate
src/client/          HUD, lobby, draft, abilities, kill feed, scoreboard, end screen, minimap, targeting indicator, camera, voice, NPC chat, Audio/, Juice/ (screen + world CombatFx + emote billboards)
contracts/           Meo404.sol + Foundry tests
bridge/              Hosted claim-handler + SIWE challenge/verify stub (viem)
```

Authority rule: money, prices, damage, match state, and purchase entitlements live on the server. Chain keys never do.

## Next suggested steps

1. Smarter bots: dive / dodge / lens are in. Next: multi-camp jungle, hold skillshots until the lead is clean, tower-dive with more allies.
2. Control / pink wards, **traveling** skillshot projectiles (hitscan + telegraph VFX are in), click-to-confirm ground targeting.
3. Brush / true fog of war (server-authoritative visibility, not just LocalTransparency).
4. Cancel-on-order recall only (keep walking without breaking channel if we add click-to-move). Replace placeholder SoundIds / emote cues / `MusicIds` beds with original meows and real loops. Uploaded emote poses instead of Part bob.
5. Surrender vote + explicit “leave champ select” without tearing down a 5v5.
6. Inner / inhibitor towers; richer post-match (damage graph, CS timeline).
7. Swap placeholder Part silhouettes / map kits for uploaded meshes (keep `HumanoidRootPart` and `MapBounds`).
8. Publish `MatchPlaceId` and playtest live reserved teleports; `GetChatGroupsAsync` so voice-eligible cats land together.
9. Accept/decline party invites, cross-server friends, party chat in lobby. Custom voice: push-to-talk, per-player mute.
10. Swap the HTTP stub for a hosted proxy so API keys never sit in the place file.
11. DataStores for cosmetics funded by yarn / meme-stock wagers.
12. Open Cloud re-verify of DataStore entitlements from the bridge; persist SIWE nonces / verified wallets beyond one process.
13. Compliance / legal review before any live Developer Product that mentions 404 / NFTs.

## License / secrets

Do not commit API keys, minter keys, `.env`, or `Secrets.luau`. `.gitignore` already drops Roblox binaries, Rojo sourcemaps, Foundry `out/` + `lib/`, and secret files.
