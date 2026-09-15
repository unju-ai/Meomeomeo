# Playtest Meo Meo Meo

Step-by-step for running the cat MOBA in **Roblox Studio** or a **published experience**. Source of truth is this Rojo tree. In Play, press **?** or hold **H** for the same keybinds.

Do not commit API keys, `ClaimApiSecret`, or any chain private key.

## 0. What you have

Playable scaffold: **hub grid** (Cat Rift / Yarn Run / Koi Pond / Yarn Party / Meme Arcade) → Cat Rift practice or queue → 14-cat draft → 3-lane fight → end screen → hub. **Yarn Run** dash + daily board. **Koi Pond** fishing. **Yarn Party** 4-cat micro-rounds (bots fill). **Meme Arcade** timed yarn-tape stall (play yarn only).

Also: reserved-server-ready queue (in-place fallback), practice bots (Hard dodge / dive / lens), voice stub, Kitty Caster, meme-stock tape, Meo404 DataStore entitlements + mint panel, **Closet drip** (hats + trails, yarn points, DataStore `MeoCloset_v1`), client SFX + juice, distinct champion silhouettes, combat VFX stubs, map art pass, **first-Practice tip cards** (Next / Skip all; lobby **Show tips**).

This is **not** a finished live-ops title. Placeholders (`0` / `""`) are Studio-safe.

The channel trio **MEO, ME and MO** now appear as talkable lobby hosts, with the shared sculptural silhouette, cobalt braincell and character dialogue. The 14 playable champions remain available. Creative sources and production assets live in [docs/creative](docs/creative/README.md).

## 1. Install tools

Pinned in `aftman.toml`: **Rojo 7.4.4**. Use the matching Studio plugin when live syncing.

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

For a standalone place, build from the repo root and open the resulting file in Studio:

```bash
rojo build default.project.json -o MeoMeoMeo.rbxlx
```

Press **Play** to generate the map and host models; these are created by server scripts at runtime. This route does not need an active Rojo connection. Rebuild after source changes. Generated place files are gitignored; commit source changes instead.

Build verification on 2026-09-15: Luau compiled 100 sources; brand/lobby + cosmetics/arcade/koi/yarn/party smokes passed. This is build verification, not a Studio playtest.

### Lobby host acceptance check

1. Start Play and check the **hub grid** title (**meo meo meo**) plus Cat Rift's **Three lanes. One shared braincell.**
2. Walk toward the three hosts near the lobby spawn. Confirm orange MEO, ivory ME and charcoal MO each show a name and **Talk** prompt. Check the eyes and cobalt forehead square from the front.
3. Talk to each host. Confirm the dialogue panel names the selected host and replies in that host's voice. Hosts should not block movement.
   - Each host opens with a distinct authored greeting. Switch hosts while a reply is pending: the new conversation should contain only the new host's greeting and subsequent messages. Closing and reopening the same host should also discard pending replies from the old conversation.
   - Send with both Enter and the Send button. If a request fails, the panel should offer a retry message. The transcript keeps the most recent 60 lines per open conversation.
4. Start a Practice match and confirm the full 14-champion draft still appears. Return to the lobby after a match and check the host prompts again.
5. With two Studio clients, queue both players and confirm live queue status stays readable and the match starts.

### Live sync

From the repo root:

```bash
rojo serve
```

1. Studio → **New place** (or an existing unpublished place).
2. Rojo plugin → **Connect** to `localhost` (default port 34872).
3. Confirm `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and `StarterPlayer.StarterPlayerScripts.Client` appeared.
4. **Play** (F5). Character loads on the night-market pad with the **hub grid** (Cat Rift / Yarn Run / Koi Pond / Yarn Party / Meme Arcade).

`*.rbxl` is gitignored. Do not treat a Studio file as source of truth.

| Disk | Roblox |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

## 3. First session — Practice (solo)

1. Hub → **Cat Rift → Play** → bot difficulty **Easy**, **Normal**, or **Hard** → **Practice match**. **← Hub** returns to the grid. After lock-in, a cream/coral **tip card** (top-left) walks move/AA/QWER/shop/recall/ward/Tab/nexus. **Next** or **Skip all**. Combat still works — the card is not a modal. Lobby **Show tips** replays anytime. Skip/finish persists (`MeoTutorial_v1` DataStore, memory fallback in Studio).
   - **Easy** — slow, panicky, sloppy CS, two items, 0.88× damage. No dodge; will not dive towers.
   - **Normal** — last-hits, leads and sidesteps skillshots, dives only with a crashing wave or a short low-HP chase, mid may clear a nearby camp.
   - **Hard** — faster, 1.22× damage, tighter CS, full build, one early ward, kill-dives, uses Whisker Lens on revealed enemy wards.
2. You are Blue Whiskers vs **3 Red (Bot)** cats. Draft a cat (Professor Whiskers / Bytekit / Nyan Rocket are easy to read). Cards show a color swatch + ears. After lock-in, you and the Red bots should have **distinct silhouettes** (ears/tail/archetype flair) and nameplates (`Champion · role`, bots keep `(Bot)`). The rift should read as a night-market: gold lane dots, indigo river, fountain lanterns, tower ears / yarn, jungle camp pedestals.
3. Walk a lane. **LMB** a bot or minion — claw flash + hit spark. Hold **Q** if the kit is a line skillshot (aim indicator), release to fire (beam/ring on confirm). Heal/shield cats show a soft burst; dashes leave a streak.
4. **4** drop a trinket. **B** at fountain → buy **Whisker Lens** → **5** if you see an enemy ward.
5. **F** recall (7s) — mint circle under your feet. **Tab** scoreboard (bots tagged).
6. Kill all **3 Red towers** until the nexus billboard says `(OPEN)` (tower bolts + death puff), then scratch the nexus.
7. End screen → **Back to lobby** or **Practice again**.

Practice **never** teleports. `MatchPlaceId` can stay `0`.

## 3b. Yarn Run (solo dash)

1. Hub → **Yarn Run**. Pick **Nyan / Shad / Chai** (NyanRocket / Shadowpounce / ChairmanMeow looks) → **Play**.
2. You teleport to a night-market ribbon far from the rift (`MeoYarnRun`). 3/4 chase cam. **A/D** (or arrows) change lanes, **Space** jumps dogs / Roomba gaps, **C** / **Ctrl** slides under laundry signs and the **laundry tunnel**.
3. **Power-ups** (server pickups, big HUD chips): cyan **SPD** bolt = Speed Burst, magenta **MAG** horseshoe = Magnet Yarn (sucks adjacent balls), mint **SHD** dome = one free hit (`SHIELD UP` / `SHIELD POP`), gold **2X** twins = Double Score window. Ticker lines match (`SPEED BURST`, `MAGNET ON`, `2X YARN`).
4. **PB / ghost:** a translucent cat replays your personal-best path (session memory). A gold **PB {meters}m** gate sits on the ribbon. HUD shows `PB score / meters`. Beat it for **NEW PERSONAL BEST** on the death card.
5. Layout **ramps with distance**: zig-zag dogs, laundry tunnel, Roomba jump gap, yarn fountain, narrow bridge, billboard dodge. Same **daily UTC seed** every run that day (HUD `Daily seed YYYY-MM-DD`) so streamers share a layout.
6. Die → fail line or **NEW PERSONAL BEST**, score / yarn / combo / PB compare, death cam pulls back. Combo ≥ 2 flashes **COMBO BREAK**. Near-misses tick **CLOSE!**. If the run lands on today's board, the death card shows **Daily rank #K**. Top 3 get a podium + ticker (`#1 YARN LORD` / `#2 YARN ACE` / `#3 YARN CREW`). **Retry dash** (same daily seed + ghost) or **Back to hub**. **Leaderboard** on the death card opens the full daily list.
7. **Daily board:** Hub Yarn Run tile **Board** (and the death-card button) lists top 10 for the UTC day: Roblox **display name**, score, meters, champion tag. DataStore `MeoYarnDaily_v1` when API Services are on; Studio without them is **Save: Memory**. Submit is server-side on death only if the score beats that player's prior for the day (rate-limited). No user ids on the public list.
8. During a run, a top-right **Daily #K** chip is the stream overlay stub (shows **Daily —** until you are on the board).
9. Help overlay (**?** / **H**) swaps to runner binds. **T** emotes still work. **G** pings do not.

Score / hits / pickups / board writes are server-authoritative. Personal best + ghost samples stay session memory (`MeoYarnBest`). Daily ranks persist when DataStore is available.

## 3c. Koi Pond (solo fishing)

1. Hub → **Koi Pond → Play**. You teleport to a lantern canal far from the rift (`MeoKoiPond`, east of the map). Cozy 3/4 dock cam. **Back to hub** returns like Yarn Run.
2. **Space** or **Click** **casts** a yarn bobber. Wait for a nibble (do not mash — an extra press spooked the canal).
3. When the lantern rail appears, **Space / Click** again to **reel**. Hit the **cream window** (middle glow) to land the cat-koi. Miss / timeout: *The loaf swam off* / *Slipped the cream window*.
4. Rarities (Meo canal, not a generic fish UI): cream loaf → peach koi → mint whisker / cobalt braincell → amber lantern → **coral crown**. Tighter window = rarer. Big pops on the HUD; **LEGENDARY KOI** ticker + coral flash for the crown.
5. **Stall log** (right) is a session collection. HUD **best catch** + tile **PB catch** are personal (session memory, no DataStore board this slice). Canal day chip is UTC like Yarn Run's daily seed.
6. Help overlay (**?** / **H**) swaps to pond binds (cast / reel). **T** emotes still work. **G** pings do not.

Cast / reel / catch / score are server-authoritative. Yarn Run board, power-ups, and Cat Rift are unchanged. Exclusive with Hub / Moba / Yarn Run (`ModeService`).

## 3d. Yarn Party (solo + bots)

1. Hub → **Yarn Party → Play**. You teleport to a night-market courtyard south of the rift (`MeoYarnParty`). High 3/4 cam so all four cats stay on stream. Empty seats fill with **LoafBot / NibBot / PurrBot** after a short countdown. A second client on the same server can hop in during lobby.
2. **Three micro-rounds** (not an obstacle-course clone): **YARN DODGE** (hop the coral yarn ball with **Space**; **WASD** to strafe), **STALL FREEZE** (when lanterns blink, stand on a **lit pillow**), then Dodge again.
3. Giant round titles, elim pops (`YARN BONK` / `WRONG PILLOW`), live scoreboard. Points: last cat standing 3, timeout survivors 2, then 1 / 0 down the elim order. After round 3: **CROWNED** podium + **Party again** or **Back to hub**.
4. Help overlay (**?** / **H**) swaps to party binds. **T** emotes still work. **G** pings do not.

Scores / elims / bots are server-authoritative. Yarn Run, Koi Pond, and Cat Rift stay exclusive and unchanged.

## 3e. Meme Arcade (solo tape)

1. Hub → **Meme Arcade → Play**. You teleport to a neon tape stall west of the rift (`MeoMemeArcade`). 3/4 cam on the ticker wall. **Play yarn only** — the HUD and stall sign say this is not real money / not a broker.
2. Start with **100 yarn**. Five cat tickers (LOAF / NYAN / CHNK / BRAIN / RUG) drift on a chaotic micro-market. **Buy** / **Sell** 1 bag at the listed price (cards, or **1–5** buy / **Shift+1–5** sell). Simple candle bars sit on each card.
3. Timed round (~28s). Mark-to-market PnL is the big green/red pop. Events shout **TO THE MOON**, **RUG PULL**, **WHALE SNEEZE**. At the bell, holdings auto-sell. **Score = profit** vs the starting wallet. Session **daily high** (UTC day, memory — light, no DataStore board).
4. **Play again** or **Back to hub**. Help overlay (**?** / **H**) swaps to arcade binds. **T** emotes still work. **G** pings do not.

Tape / wallets / events are server-authoritative and **isolated** from in-match `MemeStockService` cheer tickers. Exclusive with Hub / Moba / Yarn Run / Koi Pond / Yarn Party.

## 3f. Closet (cross-mode drip)

Hats, collars, shades, and trails/auras. **Parts only** (no meshes). **Play yarn / stall scores only** — there is no Robux cosmetic shop.

1. Hub chrome **Closet** (left of **Mint 404**), or Cat Rift stall **Closet**. Panel: disclaimer, **Save: DataStore | Memory**, closet-yarn wallet, cat silhouette preview, item list.
2. Starters **Cream Cap** + **Yarn Puff** are owned and equipped on first load. **Equip** / tap **Worn** to unequip. One hat + one trail at a time.
3. **Gold Bell** (collar) costs **25 closet yarn**. New cats start with **40**. Closet yarn is **play points**, not in-match meme-stock yarn and not Robux.
4. Stall unlocks (granted once, then persist even if a daily score resets):
   - **Coral Beanie** — Yarn Run **200m** (best distance this server, including non-PB scores)
   - **Mint Aura** — Yarn Run **400m**
   - **Canal Crown** + emote flair — catch a **legendary** koi
   - **Party Tiara** + **Moon Dust** (emote flair) — win a Yarn Party (human, not a bot)
   - **Tape Shades** — Meme Arcade daily profit **+15**
   - **Braincell Orbs** + emote flair — Arcade daily **+25**
5. Equipped drip welds onto the avatar in **hub idle**, **Yarn Run**, **Koi Pond**, **Yarn Party**, **Meme Arcade**, and **Cat Rift** lobby/match (on top of champion silhouettes). Rare flair tints **T** emote bobs. Equip / unlock lines hit the ticker (`EQUIPPED ·` / `UNLOCKED ·`).
6. Loadout persists in DataStore `MeoCloset_v1` when Studio **API Services** are on. Off = **Save: Memory** (same pattern as settings / Meo404). Bots do not wear closet drip.

Help overlay lists Closet on the hub sheet. ModeService gates are unchanged.

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
| **T** (hold) | Emote wheel (Meow, Hiss, Purr, Flex, Dance, Laugh, Cry, GG). Release or click a slice. Server cooldown; no emote while down |
| **G** (hold) | Smart ping wheel: Caution, On My Way, Assist, Enemy Missing, All Clear, Attack Here. Release or click. Team-only; cooldown. Aim at a tower/nexus/visible champ to name them |
| **Tab** (hold) | Scoreboard |
| **V** | Toggle locked follow camera |
| **Audio** (top-right) | SFX slider + mute, Music slider + mute (independent, quieter default), mute others' emotes. Mix + last Practice difficulty persist (`MeoSettings_v1`) |
| **Closet** | Hub / Cat Rift wardrobe — hats + trails, yarn points (not Robux) |
| **?** or hold **H** | This help overlay |
| Minimap click | Generic **Attention** ping (team-only). History dots linger on the map |
| Talk prompt | Fountain / jungle NPC chat (Kitty Caster, clerks, Old Tom) |
| **A / D** (Yarn Run) | Switch lane (also arrows). In the Rift, **A** is still engine strafe |
| **Space** (Yarn Run) | Jump a dog or the Roomba gap |
| **C / Ctrl** (Yarn Run) | Slide under a laundry sign / tunnel |
| **Space / Click** (Koi Pond) | Cast the yarn bobber; reel when the loaf hits the cream window |
| **WASD** (Yarn Party) | Run the courtyard. Engine jump **Space** hops the yarn |
| **Space** (Yarn Party) | Hop the coral yarn (Dodge) · walk onto lit pillows (Stall Freeze) |
| **1–5** (Meme Arcade) | Buy 1 yarn bag of LOAF / NYAN / CHNK / BRAIN / RUG |
| **Shift+1–5** (Meme Arcade) | Sell 1 bag at the listed yarn price |

Hub: **Cat Rift** / **Yarn Run** / **Koi Pond** / **Yarn Party** / **Meme Arcade** tiles, **Closet**, **Mint 404**, Audio, **T** emotes, **?**. Cat Rift stall: **Queue**, **Leave queue**, **Practice**, **Invite**, **Closet**, **← Hub**.

## 6. Meo404 in Studio (no live Robux)

This is a **Developer Product → entitlement → hosted mint** stub, not a Robux-to-crypto swap. Legal review before a live product.

1. Studio → **Game Settings → Security → Enable Studio Access to API Services** if you want DataStore `Meo404_v1` to survive Stop. Off = in-memory fallback (panel shows `Save: Memory`).
2. Leave `Nft404.DeveloperProductId = 0` and `AllowStudioMockPurchase = true`.
3. Play → hub **Mint 404** (or Cat Rift stall **Mint Meo 404**).
4. **Studio: grant mock entitlement** (or **Studio: replay last receipt**).
5. Paste a dummy `0x` + 40 hex (not the zero address) → **Link**. Panel shows **Linked (unverified)**.
6. **Mock bypass (default):** leave `AllowSiweMockBypass = true`. **Claim 404** works without a signature. Mock provider writes `0xMOCK…`. Failed claims stay **Retry claim**.
7. **Mock verify path:** **Challenge** → copy the SIWE message (optional) → paste `studio-bypass` (or a 132-char `0x` stub) → **Verify SIWE**. Panel should show **Wallet verified**. Nonces expire in 10 minutes and are one-time.
8. **Real verify:** host `bridge/claim-service` on HTTPS, set `SIWE_DOMAIN` / `SIWE_URI`, `Provider = "http"`, `AllowSiweMockBypass = false`. Sign the challenge in an external wallet and paste the signature. The place never holds a private key.
9. Stop / Play again with API Services on: slip + wallet record should return. A pre-SIWE bare `0x` string loads as unverified.

Turn **`AllowSiweMockBypass` off** before any live Robux product. Legal review before a live product.

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
| `Nft404.AllowSiweMockBypass` | `true` | Studio: claim without ECDSA. Set `false` before live Robux. |
| `Ai.Endpoint` / `Ai.ApiKey` | `""` | Only if `Ai.Provider = "http"`. Never commit a real key. |

Also for a live place:

1. Publish the experience (reserved servers and voice need this).
2. **Experience Settings → Communication → Enable Voice Chat**. Testers: age-verified 13+, voice opted in. Team Test or two live clients.
3. **Allow HTTP Requests** only if you switch AI or ClaimApi to `http`.
4. Rojo-sync (or `rojo build`) the **same** tree into lobby and match places if they are separate.
5. Queue with 2+ live clients. Expect **MATCH FOUND** then a teleport when `MatchPlaceId ~= 0`.

## 8. Audio placeholders

`src/client/Audio/SoundIds.luau` (SFX) and `src/client/Audio/MusicIds.luau` (phase beds) use engine `rbxasset://sounds/…` so git stays binary-free. Swap any `id` to `rbxassetid://YOUR_ID` after a Creator Store upload.

**SFX** and **Music** have separate sliders / mute on the **Audio** panel (top-right). Music defaults quieter (35% vs SFX 80%) and lives on `SoundService.MeoMusic`. Phase beds crossfade ~1s (Hub / YarnRun / KoiPond / YarnParty / MemeArcade / Lobby / ChampionSelect / InProgress / Ended). MatchFound and nexus stingers duck the bed briefly.

Audio sliders / mutes, mute-others-emotes, and last Practice difficulty persist in DataStore `MeoSettings_v1` when Studio API Services are on (same memory fallback as tutorial / Meo404).

The current beds reuse `action_get_up.mp3` at different speeds — placeholders only. See README "Audio & juice".

## 8b. Champion looks (placeholders)

`ChampionLooks` + `ChampionAppearance` dress locked cats from engine `Part`s (ears, tail, team collar, archetype flair). No `rbxm` / mesh binaries. `HumanoidRootPart` stays the combat box. To swap real meshes later, replace the `MeoAppearance` folder recipes and keep the same root — see README.

## 8c. Combat VFX (placeholders)

Server confirms a cast/hit, then `CombatFx` fires. Client pools short-lived Parts (plus one-shot particles). Aim indicators while holding a skill are still local. AA sparks are debounced so wave last-hits do not melt the frame.

## 8d. Map art pass

`MapBuilder` dresses the same 420×280 bounds (lane Z −80 / 0 / 80). Extra Parts are `CanCollide = false` and `CanQuery = false` so bots, tower ranges, and click-AA stay the same. Lighting is a cozy night-market (`Atmosphere` + mild bloom), not a rave.

## 8e. Cat emotes

Hold **T** in lobby or Practice for the 8-slice wheel (Meow / Hiss / Purr / Flex / Dance / Laugh / Cry / GG). Release or click a slice. Nearby clients see a billboard + Part bob and hear a Sound-kit cue. Server cooldown (~2.6s); no emote while down. **SFX → Mute others' emotes** skips their cues (billboard still shows). No animation binaries.

## 8f. Smart pings

Hold **G** in a match (Practice counts) for the 6-slice ping wheel. Minimap click stays generic **Attention**. Markers + a short line go to **teammates only** (fog: unseen enemy champs are not named). Server cooldown ~1.25s. Minimap keeps a short history flash of recent pings.

## 9. If something is quiet / missing

- No SFX: click **Audio**, unmute SFX, volume > 0. Some engine `rbxasset://sounds/` names are silent in newer Studio — swap ids.
- No music: **Audio → unmute Music**, slider > 0. Placeholder bed is a quiet loop of `action_get_up.mp3`; swap `MusicIds` for a real loop. Phase change should crossfade, not cut.
- Mint says Memory: enable Studio API Services.
- Closet says Memory: same API Services toggle (`MeoCloset_v1`). Starters still equip in-session.
- Claim says SIWE-verify: leave `AllowSiweMockBypass = true` in Studio, or Challenge → `studio-bypass` → Verify.
- Queue never teleports in Studio: expected. Publish + `MatchPlaceId`.
- Voice pill is not Ready: unpublished Solo Play cannot enable experience voice.
- Bots idle: you are still in **Champion select** — lock a cat and wait for the timer.
- Bots look like the same box: Rojo-sync `Shared.ChampionLooks` + `Server.World.ChampionAppearance`, then start a new Practice.
- No cast/hit VFX: Rojo-sync so `MeoRemotes.CombatFx` exists, then start a new Practice (FX are server-confirmed, not the hold-to-aim indicator).
- Map still looks like a green slab: Rojo-sync `Server.World.MapBuilder` and replay Practice (lighting is applied on `MapBuilder.build`).
- No tip card on first Practice: Rojo-sync `TutorialTips` + `GetTutorialStatus`. Replay from lobby **Show tips**. Attribute `MeoTutorialDone` skips auto-start.
- No emote wheel: Rojo-sync so `MeoRemotes.PlayEmote` / `EmotePlayed` exist, then hold **T** in lobby or Practice (not while down).
- No ping wheel: Rojo-sync `PingCatalog` + `MinimapPing`. Hold **G** in Practice (not lobby). Minimap click still Attention.

## 10. Still stubbed (do not expect)

Live reserved-teleport playtest in this cloud agent, uploaded cat meshes (silhouettes are primitive Parts today), fog-of-war beyond `LocalTransparency`, traveling skillshot projectiles, original SFX / music beds (placeholders loop today), compliance-cleared Robux 404 product, production SIWE domain binding + persisted nonces.
