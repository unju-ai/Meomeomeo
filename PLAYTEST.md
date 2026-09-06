# Playtest Meo Meo Meo

Step-by-step for running the cat MOBA in **Roblox Studio** or a **published experience**. Source of truth is this Rojo tree (PRs 1–16). In Play, press **?** or hold **H** for the same keybinds.

Do not commit API keys, `ClaimApiSecret`, or any chain private key.

## 0. What you have after PRs 1–16

Playable scaffold: lobby → practice or queue → 14-cat draft → 3-lane fight (AA, abilities, minions, towers, gated nexus, jungle, wards, lens, recall, Pawmart) → end screen → lobby.

Also: reserved-server-ready queue (in-place fallback), practice bots (Hard dodge / dive / lens), voice stub, Kitty Caster, meme-stock tape, Meo404 DataStore entitlements + mint panel, client SFX + juice, **distinct champion silhouettes** (primitive Parts, no mesh binaries).

This is **not** a finished live-ops title. Placeholders (`0` / `""`) are Studio-safe.

## 1. Install tools

Pinned in `aftman.toml`: **Rojo 7.4.4** (7.x). Latest Rojo is 7.7.0 (websockets + syncback). Keep **CLI and Studio plugin on the same 7.x line** — mixing 7.4 CLI with a 7.7 plugin (or the reverse) can fail to connect.

```bash
# https://github.com/LPGhatguy/aftman
aftman install
rojo --version    # expect 7.4.4 if you used this pin
```

Or install Rojo 7.x however you like: [rojo.space](https://rojo.space/).

Studio plugin (Rojo 7): [create.roblox.com — Rojo](https://www.roblox.com/library/13916111004/Rojo-7) or `rojo plugin install`.

Optional lint (this repo has `selene.toml`):

```bash
# aftman.toml also pins Kampfkarren/selene@0.31.0
selene src
```

`selene 0.31.0` against this tree: no parse errors. Three pre-existing `if_same_then_else` hits remain in `KillFeed.luau` and `MatchService.luau` (same-color / same-assignment branches). This slice does not refactor those.

## 2. Sync into Studio

From the repo root:

```bash
rojo serve
```

1. Studio → **New place** (or an existing unpublished place).
2. Rojo plugin → **Connect** to `localhost` (default port 34872).
3. Confirm `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and `StarterPlayer.StarterPlayerScripts.Client` appeared.
4. **Play** (F5). Character should load on the 3-lane map with the lobby panel.

`*.rbxl` is gitignored. Do not treat a Studio file as source of truth.

| Disk | Roblox |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

## 3. First session — Practice (solo)

1. Lobby → bot difficulty **Easy**, **Normal**, or **Hard** → **Practice match**.
   - **Easy** — slow, panicky, sloppy CS, two items, 0.88× damage. No dodge; will not dive towers.
   - **Normal** — last-hits, leads and sidesteps skillshots, dives only with a crashing wave or a short low-HP chase, mid may clear a nearby camp.
   - **Hard** — faster, 1.22× damage, tighter CS, full build, one early ward, kill-dives, uses Whisker Lens on revealed enemy wards.
2. You are Blue Whiskers vs **3 Red (Bot)** cats. Draft a cat (Professor Whiskers / Bytekit / Nyan Rocket are easy to read). Cards show a color swatch + ears. After lock-in, you and the Red bots should have **distinct silhouettes** (ears/tail/archetype flair) and nameplates (`Champion · role`, bots keep `(Bot)`).
3. Walk a lane. **LMB** a bot or minion. Hold **Q** if the kit is a line skillshot, release to fire.
4. **4** drop a trinket. **B** at fountain → buy **Whisker Lens** → **5** if you see an enemy ward.
5. **F** recall (7s). **Tab** scoreboard (bots tagged).
6. Kill all **3 Red towers** until the nexus billboard says `(OPEN)`, then scratch the nexus.
7. End screen → **Back to lobby** or **Practice again**.

Practice **never** teleports. `MatchPlaceId` can stay `0`.

## 4. Queue (2+ clients)

Defaults: `MinPlayersToStart = 2`, `MatchPlaceId = 0` (match starts **in this server**), `PadQueueWithBots = true` (fill to 3 per side).

1. Two Studio clients (Team Test / local server + players) or two published clients.
2. Both hit **Queue**. HUD shows count / ETA.
3. On **Match found** you should hear the stinger. With `MatchPlaceId = 0` (or Studio), draft starts **in place**.
4. Optional lobby **Invite** adds another player in this same server to your party stub.

Reserved teleports need a **published** experience and a real `MatchPlaceId` — see §7. Studio `ReserveServer` fails closed and starts in-place.

## 5. Keybinds (after PRs 1–12)

Same list as the in-game **?** / hold **H** panel.

| Input | Action |
| --- | --- |
| **LMB** | Lock auto-attack on an enemy champ, minion, jungle, ward, or (ungated) structure |
| **X** then click | Attack-move (walk + auto-acquire) |
| **S** | Stop attack / cancel channel orders |
| **Q W E R** | Abilities. Hold line/dash to preview; release to fire. Instant/ground fire on press |
| **4** | Trinket ward (free, 70s CD, 60s duration, one live) |
| **5** | Whisker Lens (buy at Pawmart first) |
| **B** | Pawmart — **fountain only**. Not recall |
| **F** | Recall 7s → fountain. Damage, move, AA, abilities, **S**, or **F** again cancel |
| **Tab** (hold) | Scoreboard |
| **V** | Toggle locked follow camera |
| **SFX** (top-right) | Master volume + mute |
| **?** or hold **H** | This help overlay |
| Minimap click | Team ping |
| Talk prompt | Fountain / jungle NPC chat (Kitty Caster, clerks, Old Tom) |
| **A** | Engine strafe — not rebound |

Lobby only: **Queue**, **Leave queue**, **Practice**, **Invite**, **Mint Meo 404**.

## 6. Meo404 in Studio (no live Robux)

This is a **Developer Product → entitlement → hosted mint** stub, not a Robux-to-crypto swap. Legal review before a live product.

1. Studio → **Game Settings → Security → Enable Studio Access to API Services** if you want DataStore `Meo404_v1` to survive Stop. Off = in-memory fallback (panel shows `Save: Memory`).
2. Leave `Nft404.DeveloperProductId = 0` and `AllowStudioMockPurchase = true`.
3. Play → lobby → **Mint Meo 404**.
4. **Studio: grant mock entitlement** (or **Studio: replay last receipt**).
5. Paste a dummy `0x` + 40 hex (not the zero address) → **Link**. Panel should show **Wallet linked**.
6. **Claim 404**. Mock provider writes `0xMOCK…`. Failed claims stay **Retry claim**.
7. Stop / Play again with API Services on: slip + wallet should return.

Live product later: create “Mint Meo 404” under Monetization → Developer Products, put the numeric id in `Nft404.DeveloperProductId`, publish, then the client uses `PromptProductPurchase`. `ClaimApiUrl` + `Provider = "http"` only when a hosted handler exists. **Never** put `MEO404_MINTER_PRIVATE_KEY` in the place.

Details: README Meo404 section, `bridge/README.md`.

## 7. Publish checklist (placeholders)

Fill these in `src/server/Config.luau` **locally** (do not commit secrets). `0` / `""` is the Studio stub.

| Field | Default | When you must set it |
| --- | --- | --- |
| `Match.MatchPlaceId` | `0` | Published PlaceId so queue can `ReserveServer`. Can be this lobby or a dedicated match place that also has this Rojo tree. |
| `Match.LobbyPlaceId` | `0` | Explicit “Back to lobby” PlaceId after a reserved match. `0` = remember the place they queued from. |
| `Match.MinPlayersToStart` | `2` | `6` (3v3) or `10` (5v5) for a real pop. |
| `Nft404.DeveloperProductId` | `0` | Creator Dashboard Developer Product id. `0` = Studio mock grant only. |
| `Nft404.ClaimApiUrl` | `""` | Hosted `POST /v1/meo404`. Leave empty and keep `Provider = "mock"` until the bridge is live. |
| `Nft404.ClaimApiSecret` | `""` | Shared Bearer secret with the bridge. **Not** a chain key. Never commit. |
| `Ai.Endpoint` / `Ai.ApiKey` | `""` | Only if `Ai.Provider = "http"`. Never commit a real key. |

Also for a live place:

1. Publish the experience (reserved servers and voice need this).
2. **Experience Settings → Communication → Enable Voice Chat**. Testers: age-verified 13+, voice opted in. Team Test or two live clients.
3. **Allow HTTP Requests** only if you switch AI or ClaimApi to `http`.
4. Rojo-sync (or `rojo build`) the **same** tree into lobby and match places if they are separate.
5. Queue with 2+ live clients. Expect **MATCH FOUND** then a teleport when `MatchPlaceId ~= 0`.

## 8. Audio placeholders

`src/client/Audio/SoundIds.luau` uses engine `rbxasset://sounds/…` so git stays binary-free. Swap any cue to `rbxassetid://YOUR_ID` after a Creator Store upload. Mute from the **SFX** panel.

## 8b. Champion looks (placeholders)

`ChampionLooks` + `ChampionAppearance` dress locked cats from engine `Part`s (ears, tail, team collar, archetype flair). No `rbxm` / mesh binaries. `HumanoidRootPart` stays the combat box. To swap real meshes later, replace the `MeoAppearance` folder recipes and keep the same root — see README.

## 9. If something is quiet / missing

- No SFX: click **SFX**, unmute, volume > 0. Some engine `rbxasset://sounds/` names are silent in newer Studio — swap ids.
- Mint says Memory: enable Studio API Services.
- Queue never teleports in Studio: expected. Publish + `MatchPlaceId`.
- Voice pill is not Ready: unpublished Solo Play cannot enable experience voice.
- Bots idle: you are still in **Champion select** — lock a cat and wait for the timer.
- Bots look like the same box: Rojo-sync `Shared.ChampionLooks` + `Server.World.ChampionAppearance`, then start a new Practice.

## 10. Still stubbed (do not expect)

SIWE wallet proof, live reserved-teleport playtest in this cloud agent, uploaded cat meshes (silhouettes are primitive Parts today), fog-of-war beyond `LocalTransparency`, traveling skillshot projectiles, original SFX/music, compliance-cleared Robux 404 product.
