# Playtest Meo Meo Meo

Step-by-step for running the cat MOBA in **Roblox Studio** or a **published experience**. Source of truth is this Rojo tree. In Play, press **?** or hold **H** for the same keybinds.

Do not commit API keys, `ClaimApiSecret`, or any chain private key.

## 0. What you have

Playable scaffold: **hub grid** (Cat Rift / Yarn Run / Koi Pond / Yarn Party / Meme Arcade) → Cat Rift practice or queue → 14-cat draft → 3-lane fight → end screen → hub. **Yarn Run** dash + daily/weekly board + persisted PB ghost. **Koi Pond** fishing + UTC daily catch board. **Yarn Party** 4-cat micro-rounds (bots fill). **Meme Arcade** timed yarn-tape stall + UTC daily profit board (play yarn only). **Audio → Hide my name** lists you as **Anonymous Cat** on those boards.

Also: reserved-server-ready queue (in-place fallback), practice bots (Hard dodge / dive / lens; leads traveling skillshots), voice stub, Kitty Caster, meme-stock tape, Meo404 DataStore entitlements + mint panel, **Closet drip** (hats + trails, yarn points, DataStore `MeoCloset_v1`), client SFX + juice, distinct champion silhouettes, **traveling line bolts** + click-to-confirm ground AoE, **true fog of war** (server mask + ground overlay + brush + fading last-seen ghosts), map art pass, **first-Practice tip cards** (Next / Skip all; lobby **Show tips**).

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

Build verification on 2026-09-22: Luau compiled 111 sources; combat projectile + Control Yarn stacks + vision/fog (mesh LoS: eye-height walls + thick cover, mesh raycast, 10-stud grid, match-lifetime explored OR, last-seen ghost freeze/fade) + brand/lobby + cosmetics/arcade/koi/yarn/party smokes passed; Rojo 7.4.4 builds the place. This is build verification, not a Studio playtest.

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

1. Hub → **Cat Rift → Play** → bot difficulty **Easy**, **Normal**, or **Hard** → **Practice match**. **← Hub** returns to the grid. After lock-in, a cream/coral **tip card** (top-left) walks move/AA/QWER/shop/recall/ward/fog/Tab/nexus. **Next** or **Skip all**. Combat still works — the card is not a modal. Lobby **Show tips** replays anytime. Skip/finish persists (`MeoTutorial_v1` DataStore, memory fallback in Studio).
   - **Easy** — slow, panicky, sloppy CS, two items, 0.88× damage. No dodge; will not dive towers.
   - **Normal** — last-hits, leads traveling skillshots (72 studs/s), sidesteps incoming bolts/AoEs (hang uses travel time), dives only with a crashing wave or a short low-HP chase, mid may clear a nearby camp.
   - **Hard** — faster, 1.22× damage, tighter CS, full build, one early **magenta control (pink)** ward, kill-dives, uses Whisker Lens on revealed enemy wards.
2. You are Blue Whiskers vs **3 Red (Bot)** cats. Draft a cat (Professor Whiskers / Bytekit / Nyan Rocket are easy to read). Cards show a color swatch + ears. After lock-in, you and the Red bots should have **distinct silhouettes** (ears/tail/archetype flair) and nameplates (`Champion · role`, bots keep `(Bot)`). The rift should read as a night-market: gold lane dots, indigo river, fountain lanterns, tower ears / yarn, jungle camp pedestals. **Fog of war** darkens ground outside ally vision. Your fountain, nearby living towers, and ally minions light bubbles. Red bots in river/jungle stay hidden until they walk into a bubble. When one walks back out, a faint ghost lingers at the last spot, then fades.
3. Walk a lane. Unseen ground stays dark; the minimap matches (no enemy dots in fog). Walk back: cells you already lit stay a lighter **explored-but-unseen** tint (not full black). **LMB** a bot or minion — claw flash + hit spark. You cannot AA a target you cannot see. Hold **Q** if the kit is a line skillshot (aim indicator), **release** to fire a **traveling bolt** (hits on contact, server-authoritative; client VFX follows — bolts are not clipped by the ground fog overlay). Ground AoEs (Paw Slam etc.): **first press** shows the ring, **click or press again** to confirm at the cursor; **Esc / right-click** cancels. Instant heals still fire on press. Dashes stay hold-to-aim + streak.
4. **4** drop a stealthed team-tinted trinket — the pocket it covers should **light up** for your team (and stay dark for Red). Walk a jungle **brush** pocket (NW/NE/SE/SW or river-crab): you vanish from enemies until they enter. **B** at fountain → buy **Control Yarn** (up to 2) → **6** plants a magenta pink ball (visible to everyone, slows, reveals nearby enemy trinkets, grants team vision). Buy **Whisker Lens** → **5** if you see an enemy ward. On **Hard**, the Red mid jungler may also plant a free pink.
5. **F** recall (7s) — mint circle under your feet. **Tab** scoreboard (bots tagged).
6. Kill all **3 Red towers** until the nexus billboard says `(OPEN)` (tower bolts + death puff), then scratch the nexus.
7. End screen → **Back to lobby** or **Practice again**. Fog overlay and any last-seen ghosts should vanish. Open **Yarn Run / Koi / Party / Arcade / Closet** and confirm hub stalls never paint rift fog.

Practice **never** teleports. `MatchPlaceId` can stay `0`.

## 3b. Yarn Run (solo dash)

1. Hub → **Yarn Run**. Pick **Nyan / Shad / Chai** (NyanRocket / Shadowpounce / ChairmanMeow looks) → **Play**.
2. You teleport to a night-market ribbon far from the rift (`MeoYarnRun`). 3/4 chase cam. **A/D** (or arrows) change lanes, **Space** jumps dogs / Roomba gaps, **C** / **Ctrl** slides under laundry signs and the **laundry tunnel**.
3. **Power-ups** (server pickups, big HUD chips): cyan **SPD** bolt = Speed Burst, magenta **MAG** horseshoe = Magnet Yarn (sucks adjacent balls), mint **SHD** dome = one free hit (`SHIELD UP` / `SHIELD POP`), gold **2X** twins = Double Score window. Ticker lines match (`SPEED BURST`, `MAGNET ON`, `2X YARN`).
4. **PB / ghost:** a translucent cat replays your personal-best path. Path samples persist in DataStore `MeoYarnGhost_v1` (capped ~240 points so payloads stay small; Studio without API Services is memory-only). A gold **PB {meters}m** gate sits on the ribbon. HUD shows `PB score / meters`. Pass that distance for a **BEAT YOUR GHOST** ticker. Beat the score for **NEW PERSONAL BEST** on the death card. Stop / Play with API Services on: the ghost should still be there.
5. Layout **ramps with distance**: zig-zag dogs, laundry tunnel, Roomba jump gap, yarn fountain, narrow bridge, billboard dodge. Same **daily UTC seed** every run that day (HUD `Daily seed YYYY-MM-DD`) so streamers share a layout.
6. Die → fail line or **NEW PERSONAL BEST**, score / yarn / combo / PB compare, death cam pulls back. Combo ≥ 2 flashes **COMBO BREAK**. Near-misses tick **CLOSE!**. Death card shows **Daily #K** and **Weekly #K** when you are on those boards. Top 3 **daily** get a podium + ticker (`#1 YARN LORD` / `#2 YARN ACE` / `#3 YARN CREW`). **Retry dash** (same daily seed + ghost) or **Back to hub**. **Leaderboard** opens the board with a **Daily / Weekly** toggle.
7. **Boards:** Hub Yarn Run tile **Board** (and the death-card button) lists top 10. **Daily** is the UTC day (`MeoYarnDaily_v1`). **Weekly** is the UTC week starting Monday (`MeoYarnWeekly_v1`). Roblox **display name**, score, meters, champion tag — or **Anonymous Cat** if **Audio → Hide my name** is on (`MeoSettings_v1`). Studio without API Services is **Save: Memory**. Submit is server-side on death only if the score beats that player's prior for that board (rate-limited). No user ids on the public list. Daily podium titles are unchanged.
8. During a run, a top-right **Daily #K** chip is the stream overlay stub (shows **Daily —** until you are on today's board).
9. Help overlay (**?** / **H**) swaps to runner binds. **T** emotes still work. **G** pings do not.

Score / hits / pickups / board writes are server-authoritative. Personal best + ghost samples persist when DataStore is available (`MeoYarnGhost_v1`); otherwise they last for the Studio session. Daily + weekly ranks persist on their stores. Closet drip and power-ups are unchanged.

## 3c. Koi Pond (solo fishing)

1. Hub → **Koi Pond → Play** (tile **Board** opens today's catch list without playing). You teleport to a lantern canal far from the rift (`MeoKoiPond`, east of the map). Cozy 3/4 dock cam. **Back to hub** returns like Yarn Run; HUD **Board** is the same daily list.
2. **Space** or **Click** **casts** a yarn bobber. Wait for a nibble (do not mash — an extra press spooked the canal).
3. When the lantern rail appears, **Space / Click** again to **reel**. Hit the **cream window** (middle glow) to land the cat-koi. Miss / timeout: *The loaf swam off* / *Slipped the cream window*.
4. Rarities (Meo canal, not a generic fish UI): cream loaf → peach koi → mint whisker / cobalt braincell → amber lantern → **coral crown**. Tighter window = rarer. Big pops on the HUD; **LEGENDARY KOI** ticker + coral flash for the crown.
5. **Stall log** (right) is a session collection. HUD **best catch** + tile **PB catch** are personal (session memory). **Daily board** (`MeoKoiDaily_v1`) ranks the best **single catch** score of the UTC day (rarity · name · score). Submit is server-side on each catch if it beats that player's prior catch that day (rate-limited). Display names only, or **Anonymous Cat** when hide-my-name is on. Canal day chip is UTC like Yarn Run's daily seed.
6. Help overlay (**?** / **H**) swaps to pond binds (cast / reel). **T** emotes still work. **G** pings do not.

Cast / reel / catch / score / board writes are server-authoritative. Yarn Run board, power-ups, Closet, and Cat Rift are unchanged. Exclusive with Hub / Moba / Yarn Run (`ModeService`).

## 3d. Yarn Party (solo + bots)

1. Hub → **Yarn Party → Play**. You teleport to a night-market courtyard south of the rift (`MeoYarnParty`). High 3/4 cam so all four cats stay on stream. Empty seats fill with **LoafBot / NibBot / PurrBot** after a short countdown. A second client on the same server can hop in during lobby.
2. **Three micro-rounds** (not an obstacle-course clone): **YARN DODGE** (hop the coral yarn ball with **Space**; **WASD** to strafe), **STALL FREEZE** (when lanterns blink, stand on a **lit pillow**), then Dodge again.
3. Giant round titles, elim pops (`YARN BONK` / `WRONG PILLOW`), live scoreboard. Points: last cat standing 3, timeout survivors 2, then 1 / 0 down the elim order. After round 3: **CROWNED** podium + **Party again** or **Back to hub**.
4. Help overlay (**?** / **H**) swaps to party binds. **T** emotes still work. **G** pings do not.

Scores / elims / bots are server-authoritative. Yarn Run, Koi Pond, and Cat Rift stay exclusive and unchanged.

## 3e. Meme Arcade (solo tape)

1. Hub → **Meme Arcade → Play** (tile **Board** opens today's profit list). You teleport to a neon tape stall west of the rift (`MeoMemeArcade`). 3/4 cam on the ticker wall. **Play yarn only** — the HUD and stall sign say this is not real money / not a broker.
2. Start with **100 yarn**. Five cat tickers (LOAF / NYAN / CHNK / BRAIN / RUG) drift on a chaotic micro-market. **Buy** / **Sell** 1 bag at the listed price (cards, or **1–5** buy / **Shift+1–5** sell). Simple candle bars sit on each card.
3. Timed round (~28s). Mark-to-market PnL is the big green/red pop. Events shout **TO THE MOON**, **RUG PULL**, **WHALE SNEEZE**. At the bell, holdings auto-sell. **Score = profit** vs the starting wallet. Session **daily high** stays in memory; the **daily board** (`MeoArcadeDaily_v1`) ranks that UTC day's best profit (negatives allowed; higher is better). Submit is server-side on settle if it beats that player's prior profit that day (rate-limited). Display names only, or **Anonymous Cat**.
4. **Play again**, recap **Board**, or **Back to hub**. Help overlay (**?** / **H**) swaps to arcade binds. **T** emotes still work. **G** pings do not.

Tape / wallets / events are server-authoritative and **isolated** from in-match `MemeStockService` cheer tickers. Exclusive with Hub / Moba / Yarn Run / Koi Pond / Yarn Party.

## 3f. Closet (cross-mode drip)

Hats, collars, shades, and trails/auras. **Parts only** (no meshes). **Play yarn / stall scores only** — there is no Robux cosmetic shop.

1. Hub chrome **Closet** (left of **Mint 404**), or Cat Rift stall **Closet**. Panel: disclaimer, **Save: DataStore | Memory**, closet-yarn wallet, cat silhouette preview, item list.
2. Starters **Cream Cap** + **Yarn Puff** are owned and equipped on first load. **Equip** / tap **Worn** to unequip. One hat + one trail at a time.
3. **Gold Bell** (collar) costs **25 closet yarn**. New cats start with **40**. Closet yarn is **play points**, not in-match meme-stock yarn and not Robux.
4. Stall unlocks (granted once, then persist even if a daily score resets):
   - **Coral Beanie** — Yarn Run **200m** (best distance, including non-PB scores; persists with the PB ghost store)
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
| **Q W E R** | Abilities. **Hold** line/dash, **release** to fire a traveling bolt (or dash). **Ground:** first press arms the ring; **LMB or same key** confirms at cursor; **Esc / RMB** cancels. Instant kits fire on press |
| **Esc / RMB** | Cancel armed line or ground aim (RMB still works if the camera ate the click) |
| **4** | Trinket ward (free, stealthed, 70s CD, 60s duration, one live) |
| **5** | Whisker Lens (buy at Pawmart first) |
| **6** | Control Yarn / pink ward (buy, 2 charges). Visible magenta ball; slows; reveals enemy trinkets |
| **B** | Pawmart — **fountain only**. Not recall |
| **F** | Recall 7s → fountain. Damage, move, AA, abilities, **S**, or **F** again cancel |
| **T** (hold) | Emote wheel (Meow, Hiss, Purr, Flex, Dance, Laugh, Cry, GG). Release or click a slice. Server cooldown; no emote while down |
| **G** (hold) | Smart ping wheel: Caution, On My Way, Assist, Enemy Missing, All Clear, Attack Here. Release or click. Team-only; cooldown. Aim at a tower/nexus/visible champ to name them |
| **Tab** (hold) | Scoreboard |
| **V** | Toggle locked follow camera |
| **Audio** (top-right) | SFX slider + mute, Music slider + mute (independent, quieter default), mute others' emotes, **Hide my name** (boards show **Anonymous Cat**). Mix + hide-name + last Practice difficulty persist (`MeoSettings_v1`) |
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

### Combat notes (Cat Rift)

- **Traveling skillshots:** Whiskers / Bytekit / Nyan Q (and other `targeting = "line"` kits) spawn a pooled neon bolt at **72 studs/s**. Damage ticks on the server as the bolt sweeps (~0.05s); the client only follows. Not hitscan.
- **Ground confirm:** first Q/W/E/R on a ground AoE shows the ring; **click or press again** casts at the cursor. **Esc / right-click / S** cancels. Lines and dashes stay **hold-to-aim, release-to-fire**.
- **Bots:** Normal/Hard lead with the same projectile speed (0.7s cap) and sidestep for `travel + 0.12s` so they still dodge the bolt instead of the old instant ray.
- **Pink vs trinket:** **4** is a stealthed team-tinted pillar. **6** (after Pawmart **Control Yarn**, 2 charges) is a magenta ball enemies can see. Pinks grant a bit more team vision, slow foes in 22 studs, and keep nearby enemy trinkets revealed. Hard jungle bots still drop one free pink. Both kinds feed the server fog mask.
- **Fog of war:** unseen ground is a dark overlay (10-stud grid). Vision bubbles come from living ally cats, kittens, towers/nexus, trinkets, and pinks. **Keep walls** and the four **market drums** block eye-height LoS (mid gate open; thin props do not). Minimap uses the same mask. Explored-but-unseen stays a lighter tint after you leave (server match memory, restored on reconnect; not DataStore). Jungle brush hides occupants until an ally source enters that pocket. Enemy traveling bolts hide in fog; yours stay visible. Attack-move / AA will not lock an unseen brush target; attack-move walks into last-known brush. When an enemy cat, kitten, or camp leaves vision, a client ghost fades at the last spot (~1.8s) and does not follow the live body. Server owns the set; the client only paints it. Smoke: `python3 tools/test-vision.py /path/to/luau`.
- Smoke: `python3 tools/test-combat.py /path/to/luau` (Targeting + ProjectileLogic). `python3 tools/test-items.py /path/to/luau` (Control Yarn stacks). Studio Play is still the real feel check.

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

Audio sliders / mutes, mute-others-emotes, **Hide my name**, and last Practice difficulty persist in DataStore `MeoSettings_v1` when Studio API Services are on (same memory fallback as tutorial / Meo404).

The current beds reuse `action_get_up.mp3` at different speeds — placeholders only. See README "Audio & juice".

## 8b. Champion looks (placeholders)

`ChampionLooks` + `ChampionAppearance` dress locked cats from engine `Part`s (ears, tail, team collar, archetype flair). No `rbxm` / mesh binaries. `HumanoidRootPart` stays the combat box. To swap real meshes later, replace the `MeoAppearance` folder recipes and keep the same root — see README.

## 8c. Combat VFX (placeholders)

Server confirms a cast/hit, then `CombatFx` fires. Client pools short-lived Parts (plus one-shot particles). Aim indicators while holding a skill are still local. AA sparks are debounced so wave last-hits do not melt the frame.

## 8d. Map art pass

`MapBuilder` dresses the same 420×280 bounds (lane Z −80 / 0 / 80). Extra decor Parts are `CanCollide = false` and `CanQuery = false` so bots, tower ranges, and click-AA stay the same. The four market drums in `VisionCover` are the exception: `CanQuery = true` and `MeoBlocksVision` so fog can raycast them, still `CanCollide = false` (walk-through, same as keep walls). Client click rays exclude that folder. Lighting is a cozy night-market (`Atmosphere` + mild bloom), not a rave.

## 8e. Cat emotes

Hold **T** in lobby or Practice for the 8-slice wheel (Meow / Hiss / Purr / Flex / Dance / Laugh / Cry / GG). Release or click a slice. Nearby clients see a billboard + Part bob and hear a Sound-kit cue. Server cooldown (~2.6s); no emote while down. **SFX → Mute others' emotes** skips their cues (billboard still shows). No animation binaries.

## 8f. Smart pings

Hold **G** in a match (Practice counts) for the 6-slice ping wheel. Minimap click stays generic **Attention**. Markers + a short line go to **teammates only** (fog: unseen enemy champs are not named). Server cooldown ~1.25s. Minimap keeps a short history flash of recent pings.

## 8g. Fog of war (Cat Rift)

Practice (or a live match) is the check. Hub / Yarn Run / Koi Pond / Yarn Party / Meme Arcade / Closet must **not** show the rift fog overlay.

- At spawn, fountain + nearby living towers are lit. Walk toward river: ground ahead stays dark until you (or a wave / ward) get there. **Base walls** block sight — you should not see through the keep into (or out of) fountain except via the **mid-lane gate**. The four clay **market drums** (between mid and the side lanes, off the river) hide whatever is directly behind them. Stepping sideways around a drum reveals that pocket. Fountain pillars, drum-top lamps, lane dots, and brush glass do **not** add dark pockets. Clicking a drum still aims at the ground behind it.
- Minimap: dark cells = no vision. Explored-but-unseen is a lighter dark and **stays that way after you leave** — it does not black out again. Rejoin / script reload mid-match should restore the same explored tint (server match memory, not DataStore). A new Practice starts unexplored.
- **4** in jungle lights a team bubble. Red should not see your stealthed trinket unless they walk on it, lens it, or a pink reveals it.
- **6** magenta pink is visible to Red even in fog, and still grants your team a vision bubble + slow + trinket reveal. Pink vision still respects walls and thick cover (a drum between the pink and a cell stays dark).
- Stand in a labeled brush pocket: you should drop off the enemy minimap until they enter. You can still see the lane from inside. **LMB / attack-move (X)** must **not** lock an unseen brush target. Attack-move toward a last-seen brush pocket walks **into** that last-known tile (never the hidden live body).
- When a Red cat, kitten, or jungle camp **leaves** your vision, a translucent ghost of that unit stays at the last spot and facing you saw, then fades (about 1.8s). It does not slide toward where they actually went. Seeing that unit again removes the ghost immediately. Ghosts are local juice in `Workspace.MeoLastSeen`: not wards, not minimap dots, and not attack targets. **LMB** still refuses a hidden target. **Attack-move (X)** on the hidden body still walks to last-known brush, not the live tile.
- Enemy traveling **Q bolts** hide while the projectile is in unseen/unexplored fog, including ground hidden behind a drum. **Your own** bolt stays visible. Server still simulates hits. Pink wards, brush, fog memory, last-seen ghosts, and hub / Closet / Yarn Run / Koi / Party modes are unchanged.
- After **Back to lobby**, the overlay and any ghosts are gone and hub hosts / Closet look normal.

Server authority: `VisionService` builds `fogBits` + match-lifetime `exploredBits` + visible unit ids (radius + brush + eye-height mesh LoS). Memory resets on match start/stop only. Keep walls and upright cover are occlusion volumes; parts tagged `MeoBlocksVision` that are meshes, wedges, or tilted are `Workspace:Raycast` at eye height (a hit blocks, a miss does not open a wall). AA / attack-move / pings refuse fogged champs; attack-move can path to last-known brush. The client fades a last-seen ghost from visibility transitions (`LastSeenGhostLogic`); that ghost is not replicated and does not update `fogBits`. `python3 tools/test-vision.py` covers grid pack, brush, wall LoS, drum cover, thin/short reject, mesh-corner probe, mask OR, and ghost freeze/fade, not Studio rendering.

### Studio live-pass (mesh LoS)

These are not covered by the Luau smoke:

1. Blue fountain: side lanes stay dark through the keep; the **mid gate** stays lit. A cat just outside the gate is visible; one behind the north wall is not.
2. Walk to a clay drum between mid and top (west of the river, north of mid). An enemy directly across the drum is hidden; a step to the side reveals them. The lamp on the drum does not grow the shadow.
3. Drop or temporarily tag a thick `MeshPart` with `MeoBlocksVision`. Sight stops on the mesh, and the square around it does not go fully dark. Untagged neon towers, brush, and pillars stay see-through.
4. A pink (**6**) on one side of a drum does not light the far side. Your own Q bolt stays visible in that shadow; an enemy bolt does not.
5. Explored tint, reconnect restore, brush AA refuse, attack-move into last-known brush, and the ~1.8s ghost still behave as before.
6. After **Back to lobby**, fog and ghosts are gone. Hub, Closet, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade never show the rift overlay.
7. Click-to-move and attack-move on a drum still hit the ground or the unit behind it, not the drum.

## 9. If something is quiet / missing

- No SFX: click **Audio**, unmute SFX, volume > 0. Some engine `rbxasset://sounds/` names are silent in newer Studio — swap ids.
- No music: **Audio → unmute Music**, slider > 0. Placeholder bed is a quiet loop of `action_get_up.mp3`; swap `MusicIds` for a real loop. Phase change should crossfade, not cut.
- Mint says Memory: enable Studio API Services.
- Closet says Memory: same API Services toggle (`MeoCloset_v1`). Starters still equip in-session.
- Yarn ghost / board says Memory: same toggle (`MeoYarnGhost_v1`, `MeoYarnDaily_v1`, `MeoYarnWeekly_v1`, `MeoKoiDaily_v1`, `MeoArcadeDaily_v1`). Ghost still works for the current Studio session.
- Claim says SIWE-verify: leave `AllowSiweMockBypass = true` in Studio, or Challenge → `studio-bypass` → Verify.
- Queue never teleports in Studio: expected. Publish + `MatchPlaceId`.
- Voice pill is not Ready: unpublished Solo Play cannot enable experience voice.
- Bots idle: you are still in **Champion select** — lock a cat and wait for the timer.
- Bots look like the same box: Rojo-sync `Shared.ChampionLooks` + `Server.World.ChampionAppearance`, then start a new Practice.
- No cast/hit VFX: Rojo-sync so `MeoRemotes.CombatFx` exists, then start a new Practice (FX are server-confirmed, not the hold-to-aim indicator).
- Map still looks like a green slab: Rojo-sync `Server.World.MapBuilder` and replay Practice (lighting is applied on `MapBuilder.build`).
- Whole rift stays fully bright in Practice: Rojo-sync `Shared.VisionLogic` + `Client.Juice.FogOfWar`. Overlay is client-only Parts named `MeoFog`.
- No fading ghost when a bot walks into fog: Rojo-sync `Shared.LastSeenGhostLogic` + `Client.Juice.LastSeenGhosts`. Ghosts are client-only parts in `Workspace.MeoLastSeen` (not server entities). They only appear after you have seen that unit once this match.
- Fog stays on after the match / in Yarn Run: leave Practice via **Back to lobby** first; hub modes call `FogOfWar.setEnabled(false)`.
- No tip card on first Practice: Rojo-sync `TutorialTips` + `GetTutorialStatus`. Replay from lobby **Show tips**. Attribute `MeoTutorialDone` skips auto-start.
- No emote wheel: Rojo-sync so `MeoRemotes.PlayEmote` / `EmotePlayed` exist, then hold **T** in lobby or Practice (not while down).
- No ping wheel: Rojo-sync `PingCatalog` + `MinimapPing`. Hold **G** in Practice (not lobby). Minimap click still Attention.

## 10. Still stubbed (do not expect)

Live reserved-teleport playtest in this cloud agent, uploaded cat meshes (silhouettes are primitive Parts today), original SFX / music beds (placeholders loop today), compliance-cleared Robux 404 product, production SIWE domain binding + persisted nonces. Fog is a 10-stud cell mask + eye-height mesh LoS (walls, thick cover, raycast for non-box parts) + unit hide + client last-seen ghosts — not per-pixel shaders.

## Hub cast integration (2026-09-15)

The sixth grid slot is **Meet the cats**, beside the five playable modes. Click MEO, ME and MO and verify each opens the matching greeting. Switch cats while a reply is pending and confirm the old reply stays out of the new conversation. Start each game mode from an open chat and confirm the chat closes. Check the portraits and text on desktop and phone; visual Studio validation is still pending.

Verified locally: all 111 Luau sources compile; combat projectile, Control Yarn stacks, **vision/fog + brush + mesh LoS (walls, drums, thin-prop reject, mesh ray probe) + match-lifetime exploredBits + last-seen ghost freeze/fade**, brand/hub, Yarn Run (incl. stall-board ranking + Anonymous Cat), Koi Pond, Yarn Party and Meme Arcade smoke suites pass; Rojo 7.4.4 builds `MeoMeoMeo.rbxlx`. These checks do not replace a Studio playtest.

## Responsive hub (2026-09-18)

The hub fits inside the viewport with a 780 × 560 maximum. Its six cards reflow to three, two or one column, with vertical scrolling when needed. On narrow screens, Closet and Mint move below the title and tagline. Text and portraits keep their normal size.

In Studio's device emulator, check 375 × 812 portrait, 812 × 375 landscape and a desktop window. Scroll to **Meet the cats**, open each host, and verify the five Play buttons, Closet, Mint and leaderboard controls remain reachable. Rotate the device while the hub is open and check the column count changes without resetting the selected runner. Actual device rendering and touch behavior remain unverified.

Automated verification: 108 Luau sources compile and all nine repository smoke suites pass, including one/two/three-column hub layout and narrow-header checks.

## Chat usability (2026-09-18)

The chat panel fits the viewport up to 340 × 280 and appears above the hub. Send a message and check the waiting indicator; clicking Send or pressing Enter again should preserve the next draft without sending a duplicate. A reply restores Send. Blank messages do nothing.

Build a longer conversation: messages should stay in order and follow the latest reply when already at the bottom. Scroll up and confirm an incoming reply leaves your reading position alone. Sending a new message resumes following. Reopening a host clears the old conversation and waiting state. Validate these behaviors in Studio, including touch keyboard open/close; keyboard occlusion has not been verified.

## Talking-cat hub guide (2026-09-19)

Ask each host about Cat Rift, Yarn Run, Koi Pond, Yarn Party and Meme Arcade. The reply should describe the selected game, point to its hub Play button, and end with a host-specific aside. Try “help”, uppercase names, “YARN-RUN”, “fishing”, and “rift or koi?”; help and multiple-game questions should list the open stalls. Unrelated conversation should retain the existing authored lines. Ordinary NPC behavior is unchanged.

These authored guide answers run before either mock or HTTP AI completion. They do not need API keys. Meme Arcade is described as simulated play-yarn trading. The chat placeholder tells players how to discover the guide.

Verified: all 109 Luau sources compile; brand/chat regression checks cover all 15 host/game pairs, aliases, word boundaries, menu replies and ordinary NPC fallback. Studio interaction testing remains pending.

## Tappable host questions (2026-09-19)

Open MEO, ME or MO. The topic row contains **All games** followed by each playable game from `ModeCatalog`. Swipe horizontally to reach the later questions. Tapping a topic sends it through the same chat request path; it does not launch a game or erase the text input draft. While a reply is pending, additional topic taps should do nothing. Switching hosts resets the topic scroll. Ordinary NPCs hide this row and keep the compact chat size.

The host panel can grow to 340 × 332 while remaining bounded by its parent viewport. Verify topic scrolling, 44-pixel-high buttons, transcript space and text entry with Studio's phone emulator. Automated checks cover all six questions, pending-request suppression, preserved drafts, ordinary NPC behavior and the existing host guide; 109 sources compile and the Rojo place builds. Touch rendering remains unverified.
