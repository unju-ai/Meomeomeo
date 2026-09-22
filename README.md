# Meo Meo Meo

A **night-market cat game hub** for Roblox. The lobby is a **mode-select grid** (yarn/coral stalls, Meo branding — not a Fortnite Discover clone). **Cat Rift** is the 3-lane MOBA. **Yarn Run** is a streamable infinite 3-lane dash. **Koi Pond** is a cozy fishing stall. **Yarn Party** is a 4-cat micro-round bash. **Meme Arcade** is a timed yarn-tape stall (play yarn only — not real money). **Closet** drip (hats + trails) travels across those modes.

**Three lanes. One shared braincell.** The channel's orange **MEO**, ivory **ME**, and charcoal **MO** are now talkable lobby hosts alongside the existing champion roster. See the [unified creative direction and art](docs/creative/README.md) and the [Robinhood Chain pairing status](docs/robinhood-chain-pairing.md).

On the Rift, every champion and NPC is a cat, lanes and nexuses are the core loop, and **voice chat is first-class**. Players queue or Practice, lock a cat, and scratch the enemy nexus. Teammates talk over Roblox voice (team routing when the Audio API is available). Fountain shopkeepers, a jungle coach, and a play-by-play announcer talk back through an AI chat interface that **runs on a mock provider** until you plug in a real key.

Meme stocks are a **side system**: champion tickers drift in the HUD and bump on kills. They are not the game.

**Meo404** is an experimental lobby/meta flow: a Roblox Developer Product (Robux) grants a **claim entitlement**. A separate hosted service may later mint an ERC-404-style asset (1 whole token ↔ 1 NFT) to a linked wallet. This receipt-linked flow has not been established as production-ready or permitted merely because minting happens off-platform. It is not a stock token or a live Robinhood Chain integration.

This repo is a playable **scaffold** (architecture + stubs), not a finished live-ops title.

**Want to run it today?** Follow **[PLAYTEST.md](PLAYTEST.md)** (Rojo → Practice → keybinds → Meo404 Studio mock → publish checklist). In Play, click **?** or hold **H**.

## What’s in the scaffold

- Rojo-ready `src/` layout that syncs into Roblox Studio
- Night-market **hub grid** (all five stalls live: Cat Rift / Yarn Run / Koi Pond / Yarn Party / Meme Arcade) plus **Yarn Run** 3-lane dash (daily seed, power-ups, persisted PB ghost, daily/weekly boards), **Koi Pond** fishing + UTC daily catch board, **Yarn Party** 4-cat micro-rounds, **Meme Arcade** yarn-tape rounds + UTC daily profit board, **Closet** hats/trails that persist across those modes, and **Audio → Hide my name** (**Anonymous Cat** on public boards)
- Match lifecycle: **Lobby → Champion select → In progress → Ended**
- Matchmaking stub (queue for 2+ players) plus **solo practice**
- Fourteen cat champions (original six plus Robot / Cyborg / Mystic / Wizard / Sorcerer / Warrior / Rogue / Esper archetypes) with Q / W / E / R stubs and **distinct Part silhouettes** (no mesh binaries)
- Lane minion waves, outer scratching posts + inner lantern stalls, tower/nexus aggro, nexus gating, **fog of war**, Pawmart item shop
- Champion auto-attack, assist gold, levels 1–18, death timers, kill feed, jungle camps, scoreboard, fountain regen, minimap
- **Recall (F)** to fountain (channel circle under feet), **match end screen** (victory/defeat, team KDA, MVP, post/stall/core counts, structure timeline), clean return to lobby
- Trinket wards (**4**), Pawmart **Whisker Lens** (**5**), buyable **Control Yarn / pink** (**6**, 2 charges), **traveling line skillshots**, hold-to-aim dashes, click-to-confirm ground AoE, destroyable enemy wards
- Hold **G** smart pings (team-only wheel + minimap Attention); visible tower/champ names in the line
- 3-lane map placeholder: bases, outer scratching posts, inner lantern stalls, nexuses, river, jungle, fountain cats
- Voice module wrapping `VoiceChatService` (team access lists, safe Studio fallback)
- AI NPC talk stubs (Pawmart clerks, Old Tom, Kitty Caster) with mock + HTTP hook
- Three channel hosts (MEO / ME / MO) with shared identities, authored dialogue and non-colliding lobby stand-ins
- Optional yarn / meme-stock ticker on champions
- Playful HUD: hub grid, Cat Rift lobby, Yarn Run HUD, Koi Pond HUD, Yarn Party HUD, Meme Arcade HUD, **Closet** wardrobe, draft, ability bar, kill feed, **Tab scoreboard**, minimap, voice pill, NPC chat, **Mint Meo 404** panel, **Audio** (SFX + Music + Hide my name), hold **T** emote wheel, **?** / hold **H** help, first-Practice **tip cards**
- Lightweight client SFX + phase music beds (crossfade) + screen juice (hit flash, level-up pop, tower/nexus shake)
- Combat VFX stubs: **pooled traveling bolts** for line Qs, ability beams/rings, AA claw + hit spark (debounced), tower bolts, structure death puffs, shield bubble, stun stars, recall circle
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
5. Press Play. You land on the **hub grid**. **Cat Rift → Practice** for the MOBA loop, **Yarn Run** for the dash, **Koi Pond** for fishing, **Yarn Party** for 4-cat micro-rounds, or **Meme Arcade** for yarn tickers. Hub **Closet** equips hats/trails. **?** or hold **H** lists keybinds for the current stall.

`default.project.json` maps:

| Disk | Roblox |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` (Script) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (LocalScript) |

Place binaries (`*.rbxl`) are gitignored — source of truth is this tree.

### Playtest tips

- **Hub** — pick **Cat Rift** (MOBA Practice/Queue), **Yarn Run** (3-lane dash), **Koi Pond** (fishing), **Yarn Party** (4-cat micro-rounds), or **Meme Arcade** (yarn tape). **Closet** / Mint / Audio / **T** emotes / **?** stay on the chrome. All five tiles are live.
- **Closet** — hub or Cat Rift **Closet**. Starters Cream Cap + Yarn Puff. Buy **Gold Bell** for 25 closet yarn (start 40; play points, not Robux). Unlock Coral Beanie / Mint Aura from Yarn Run distance, Canal Crown from a legendary koi, Party Tiara + Moon Dust from a party win, Tape Shades / Braincell Orbs from arcade daily profit. Drip shows in every mode; loadout saves on `MeoCloset_v1` (Studio memory fallback). See PLAYTEST §3f.
- **Yarn Run** — pick Nyan / Shadow / Chairman → Play. **A/D** lanes, **Space** jump, **C** slide. Grab **SPD / MAG / SHD / 2X** pickups. Chase the **PB ghost** (persists across Play sessions when API Services are on). Pass the PB gate for **BEAT YOUR GHOST**. Same **daily seed** all day. Die to post **daily + weekly** boards (hub **Board** Daily/Weekly toggle / death-card **Leaderboard**; daily top-3 podium ticker). Stream chip **Daily #K**. **Audio → Hide my name** lists you as **Anonymous Cat**. Score / pickups / board writes are server-authoritative.
- **Koi Pond** — Play from the hub tile (**Board** for today's catches). **Space / Click** casts a yarn bobber; wait for a nibble; reel in the **cream window** (lantern rail, not a stock fishing meter). Catch cream / peach / mint / cobalt / amber / **coral crown** cat-koi. Stall log + best catch. UTC daily board ranks the best **single catch** (`MeoKoiDaily_v1`). **LEGENDARY KOI** ticker on the crown. **Back to hub** exits like Yarn Run. Exclusive with the Rift and Yarn Run.
- **Yarn Party** — Play from the hub. Lobby shows **seats 1–4** and a countdown; **LoafBot / NibBot / PurrBot** hold empty seats until a friend takes one. Mid-round Play waits for the next party. **WASD** + **Space** hop. Three rounds: Yarn Dodge, Stall Freeze (lit pillows), Dodge again. Scoreboard + **CROWNED** podium (**Party again**). Exclusive with other modes.
- **Meme Arcade** — Play from the hub (**Board** for today's yarn profit). Timed yarn-tape round: tap **Buy / Sell** (or **1–5** / **Shift+1–5**) on LOAF / NYAN / CHNK / BRAIN / RUG. Candles, wallet, bust/boom events (**RUG PULL** / **TO THE MOON**). Score is yarn profit. UTC daily board (`MeoArcadeDaily_v1`) ranks that day's best settle (negatives allowed). **Play yarn only — not real money.** Isolated from in-match meme stocks. Exclusive with other modes.
- **Practice match** — from the Cat Rift stall: one player on Blue vs **3 AI cats** on Red (top / mid / bot). Toggle **Easy / Normal / Hard**. Attack bots, then each lane's scratching post, its lantern stall, then the nexus.
- **Queue** — lobby shows count / ETA / match-found. Default `MinPlayersToStart = 2` (set **6** or **10** for a real pop). With `MatchPlaceId = 0` the match starts **in this server**. Reserved servers need a published experience (see below).
- **LMB** — lock a basic attack on an enemy kitten, champion, or structure. The server checks range, cadence, item damage, and vision (you cannot AA a fogged target). Confirmed swings show a claw flash + debounced hit spark. **X then click** is attack-move (walk + auto-acquire; into last-known brush, not a hidden body). **S** stops. **A** stays as strafe.
- **Q W E R** — aim with the mouse; the server validates range, mana, cooldown, and deals damage to enemy cats, **minions**, wards, and (if ungated) structures.
  - **Line** (Professor Whiskers / Bytekit / Nyan Q, etc.): **hold** to see the path, **release** to spawn a **traveling projectile** (`Config.Combat.ProjectileSpeed` = 72 studs/s). Hits apply **on contact** (sweep uniqueness) or at the end of the line — server-authoritative. Client VFX is a pooled neon bolt that follows the same origin→dest timing.
  - **Dash**: hold to preview, release to blink + streak (still instant on the server).
  - **Ground AoE**: **first key** arms the ring at the cursor; **LMB or the same key** confirms the cast; **Esc / right-click** cancels. **S** also clears the indicator.
  - **Instant** (self heal/shield): fires on press.
- **4** — free **trinket** (stealthed team-tinted pillar, 70s cooldown, 60s duration, one live). Replacing yours pops the old one.
- **5** — Whisker Lens sweep (buy at Pawmart). Reveals and damages enemy wards in a short radius.
- **6** — **Control Yarn / pink ward** (buy at Pawmart, 75g, **2 charges**). Magenta ball, visible to everyone, 90s, 90 HP. Team vision (slightly larger radius), **slows** enemies in 22 studs (0.7×), and **reveals** enemy trinkets in 36 studs. One live pink per owner. Hard jungle bots still plant one for free.
- **Tab** (hold) — scoreboard: KDA, CS, gold, level, items, team totals.
- **V** — toggle a simple locked follow camera (north-up, overhead).
- **B** — Pawmart (fountain only). **Not recall.**
- **F** — recall: 7s channel, server teleports you to your fountain. **A new move (WASD / stick or a ground click), attack, attack-move, ability cast, or damage cancels it.** Camera, help, emotes, pings, and opening Pawmart do not.
- **Minimap** (bottom-right) — lanes, towers, nexuses, allies, **fog overlay**, visible enemies/minions, and visible jungle camps (amber). Unseen enemies stay off the map. Click it to ping teammates.
- **Audio** (top-right, under voice) — SFX and Music sliders / mute, independent. **Hide my name** shows **Anonymous Cat** on Yarn / Koi / Arcade boards. Mix + hide-name + mute-others + last Practice difficulty persist (`MeoSettings_v1`). Sounds and beds are placeholders (`rbxasset://sounds/…`); swap ids in `SoundIds.luau` / `MusicIds.luau`.
- **?** or hold **H** — in-game control sheet (same list as PLAYTEST.md). First Practice also shows a non-modal tip card (Next / Skip all). Lobby **Show tips** replays; dismiss persists on `MeoTutorialDone` / DataStore `MeoTutorial_v1` (memory fallback in Studio).
- Walk up to a blocky fountain / jungle cat and use the **Talk** prompt.
- **Practice loop:** first Practice shows a **non-modal tip card** (Next / Skip all; lobby **Show tips** replays). Lock **Professor Whiskers** (or Bytekit / Nyan Rocket) → confirm silhouettes + nameplates → walk a gold-dotted lane and fight a bot + wave → hold **Q**, release a traveling bolt → ground kits: press then click → **4** trinket → **B** Control Yarn + **6** pink → **F** recall → Tab → each lane's scratching post, then its lantern stall, until the nexus reads `(OPEN)` → smash nexus. Two-player queue also pads empty slots with bots up to 3 per side.

## How the MOBA loop works

```
Hub grid  →  Closet  →  equip hat + trail  →  any stall (drip stays on)
Hub grid  →  Cat Rift stall  →  Queue / Practice  →  Champion select  →  Fight  →  Nexus down  →  End screen  →  Hub
Hub grid  →  Yarn Run  →  dash  →  summary  →  Retry / Hub
Hub grid  →  Koi Pond  →  cast / reel  →  daily catch board  →  Hub
Hub grid  →  Yarn Party  →  micro-rounds  →  CROWNED  →  Retry / Hub
Hub grid  →  Meme Arcade  →  tape round  →  settle  →  daily profit board  →  Retry / Hub
```

- **Server owns** gold, health, mana, XP, levels, death timers, auto-attacks, recall teleports, wards, vision, structure HP, and match phase. Clients send intent (`UseAbility`, `IssueAttack`, `AttackMove`, `IssueMove`, `PlaceWard`, `UseLens`, `StartRecall`, `SelectChampion`); they never set prices or wallets.
- **Teams:** Blue Whiskers vs Red Paws (`Teams` service). Practice puts you on Blue and fills Red with practice bots.
- **Practice bots:** `BotService` spawns dummy champion models (negative `userId`, name suffix `(Bot)`). Combat is the same server path as players (`issueAttackFor` / `useAbilityFor`). **Easy** thinks slowly, retreats early (~42% HP), AAs anything, no lead/dodge/dive IQ, buys Longclaw + Yarnplate, 0.88× damage, will not walk under enemy towers, and **never jungles**. **Normal** last-hits, leads line shots using `Config.Combat.ProjectileSpeed` (72 studs/s, 0.7s cap), sidesteps incoming line/ground casts (dodge hang uses the bolt's travel time), dives only with a crashing wave or a short low-HP chase. Once the allied wave is past the river, mid walks to the **nearest own-side camp** and finishes it: a clearly closer camp can replace a walk that has not connected, a hurt camp is not dropped when the wave crashes back, and a champion has to be within ~22 studs to pull them off a healthy camp (under ~55% HP they finish anyway). **Hard** is faster, 1.22× damage, tighter CS, fuller build (incl. Whisker Lens), one early **magenta control ward** after they leave the fountain, dives to finish a kill, and uses lens when an enemy ward is revealed nearby. Hard mid runs a **route** — own pigeon pack, own yarn golem, near river crab, far river crab — and keeps that target between think ticks. A camp under ~40% HP is finished even if a champion is on them; a healthy camp is dropped only for a champion inside ~32 studs. When the route is down they **rotate** to the furthest allied wave, biased toward a lane where an enemy was in team vision during the last 8 seconds (pinks and trinkets count). They do not chase a hidden body. Own-side camp spots and whether those camps are up are map knowledge (the alive list bots already had — mild camp omniscience, not a champion wallhack). Top and bot stay in lane. Decisions live in `Shared.JungleBotLogic`. Queue matches fill each side to `Config.Bots.QueueFillTo` when `Match.PadQueueWithBots` is on (uses the last practice difficulty). Practice is always **in-place** (never teleports).
- **Queue / reserved servers:** `MatchmakingService` + `MatchTeleport`. Enough humans (or max-wait + bots) either start draft here or `ReserveServer(MatchPlaceId)` and teleport with seat/team data. The reserved instance reads `GetJoinData().TeleportData` and boots champion select. Failures (Studio, unpublished, bad PlaceId) **fall back in-place**. Party invite stub: add another player in this lobby server.
- **Champions:** data in `src/shared/ChampionCatalog.luau`. Original six — Chairman Meow, Nyan Rocket, Chonk Knight, Professor Whiskers, Scammy McMittens, Grandma Fluff — plus **Bytekit** (Robot, Mage), **Chromeclaw** (Cyborg, Bruiser), **Oracle Paws** (Mystic, Support), **Archmeow** (Wizard, Mage), **Hexkit** (Sorcerer, Mage), **Sir Scratchalot** (Warrior, Bruiser), **Shadowpounce** (Rogue, Assassin), **Mindwhisker** (Esper, Mage). Same-team duplicate locks are rejected. Draft UI scrolls. Locked cats get a **readable silhouette** (see below).
- **Combat extras:** shield absorb and a short WalkSpeed stun stub (server-authoritative) for the new kits.
- **Map:** `src/server/World/MapBuilder.luau` builds a 3-lane rift with a night-market art pass (lane dots, indigo river, fountain kits, tower ears / yarn, **lantern stalls**, jungle camp pedestals, soft brush). Same `MapBounds` / lane Z as the minimap. Each lane has an outer scratching post (`x = ±90`) and an inner lantern stall (`x = ±132`) before the yarn core (`x = ±168`). Layout and gates live in `Shared.StructureLogic`. Structures are tagged parts; when a **nexus** hits 0 HP the other team wins.
- **Combat:** `CombatService` applies heals, **direction dashes** (clamped to range), **traveling line skillshots** (`Shared.ProjectileLogic`, pooled, max 24 live), and ground AoE. `Shared.Targeting` picks the mode. Line hits tick every 0.05s along the bolt; damage is server-side. **Auto-attacks** tick on the server (range, windup, interval, AD from items). Abilities and AAs last-hit minions/wards and respect nexus gating + vision.
- **Assists:** if an ally damaged a champion within 8s of the kill, they get assist gold/XP (`AssistGold = 60`, kill bounty stays `180`). Minion last-hits stay last-hit only.
- **Levels 1–18:** shared `Progression.luau`. XP to next level = `40 + (level-1)*28`. Last-hits (`18` XP), nearby minion deaths (`10` XP in 42 studs), kills (`80`), assists (`30`). On level-up: +72 HP, +28 mana, +3 AD, +4 AP. **Ranks auto-assign** (Q then W then E, max 5). **R unlocks at 6**, ranks again at 11 and 16. No + buttons.
- **Death:** soft-death (character stays, combat drops). Respawn = `6 + (level-1)*0.55` seconds at your fountain with full HP/mana. HUD shows the timer. Kill/assist gold unchanged.
- **Kill feed:** top-of-screen cat copy for kills, towers, nexus, and level-ups (`KillFeed`).
- **Minion waves:** every ~22s both teams spawn 3 kittens per lane. They walk toward the enemy nexus, fight, and grant last-hit gold.
- **Tower AI:** living posts, lantern stalls, and the nexus shoot the champion who recently hit an ally, else the nearest enemy champ, else the nearest minion. Stalls hit harder (`InnerDamage`) and have more HP than posts. Shots use the same aggro window. Stall bolts are warm lantern gold.
- **Structure gating:** a lantern stall ignores damage until **that lane's scratching post** is down (`(gated)` on the billboard). A nexus ignores damage until **all 3 posts and all 3 stalls** on that team are down. Billboard reads `(gated)` then `(OPEN)`. Same `TowerGold` for posts and stalls. Minions still cut toward the core at `|x| ≥ 145`, which is past the stall.
- **Vision / fog of war:** server builds a visibility set every ~0.25s (`VisionUpdated` + packed `fogBits` + match-lifetime `exploredBits`). Living **ally champions**, **minions**, **towers/nexus**, **trinkets**, and **pink wards** each grant a radius bubble (`Config.Vision`). **Base walls** and **thick cover** (the four market drums between the lanes) block eye-height vision rays. The mid-lane gate stays open. Thin props, lanterns, brush volumes, and flat floors do not occlude. MeshParts tagged `MeoBlocksVision` are raycast on that same layer so a bounding box does not paint extra dark corners. The client darkens ground outside that mask (10-stud grid) and hides unseen enemies. Explored-but-unseen cells keep a lighter tint after you leave (match memory only — reconnect restores it; not DataStore). Dead cats do not grant vision. You cannot AA onto a fogged / in-brush target. Attack-move walks into last-known brush instead of locking the hidden body. When an enemy champion, kitten, or jungle camp leaves vision, the client fades a ghost at the last spot and facing it saw (~1.8s, `LastSeenGhostLogic`). The ghost is local juice: it does not track the live body, is not a minimap dot, and is not a new vision source. Enemy traveling bolts hide in unseen fog; your own stay visible.
- **Brush:** six jungle pockets (`Shared.VisionLogic`) block vision of occupants until an ally source **enters that pocket**. You can still see out. Lanes stay open. Pink true-sight on trinkets is unchanged.
- **Trinket ward (4):** free. Server places a stealthed team-colored pillar (`WardService`) that feeds `VisionService` for 60s. One trinket per player; 70s cooldown. Not shop — **B stays Pawmart**.
- **Control Yarn / pink (6):** Pawmart consumable, 75g, max **2** charges. Magenta ball (visible, not stealthed), 90s / 90 HP, one live per owner. Team vision uses `ControlRadius` (48). Enemies in `ControlSlowRadius` walk at `ControlSlowMul`. Nearby enemy trinkets get `revealedUntil` refreshed (`ControlTrueSight` / `ControlRevealSeconds`). **Hard** jungle bots still call `placeControlFor` once (no charge). Destroyable like trinkets (AA / lens / skillshots).
- **Whisker Lens (Pawmart, 180g):** unique. **5** reveals enemy wards in 32 studs for 5s and deals 80 damage to them (trinkets 60 HP, pinks 90 HP). Enemy **trinkets** are stealthed unless revealed, you stand within 14 studs, or a pink is nearby. Pinks are always on the map.
- **Pawmart:** at your fountain (or talk to the clerk), press **B** and spend match gold on Longclaw / Yarnplate / Mana Treat / Pounce Boots / **Whisker Lens** / **Control Yarn**. Server checks gold and location. Longclaw raises AA damage. **B is shop only — recall is F, trinket is 4, pink is 6.**
- **Recall:** press **F** (not B). Server starts a 7s channel (`Config.Combat.RecallSeconds`), roots you, then `PivotTo` your fountain. A **new** move order cancels immediately (`IssueMove`: WASD / stick after you release the direction you were holding, or a ground click that walks without auto-acquiring). AA, attack-move, a validated ability, wards, lens, **S**, or **F** again also cancel. Champion/minion/tower/jungle damage still cancels. A shove past `RecallMoveCancel` (2.5 studs) still cancels while you are rooted. Camera, help, emotes, pings, and opening Pawmart do not. Fountain regen still ticks while you channel. The mint circle and channel bar clear as soon as the server drops the channel.
- **Fountain regen:** alive + inside fountain radius → `48` HP and `56` mana per second (server tick). Out in lane it's the slow combat regen.
- **Jungle:** six neutral camps (Yarn Golems, Pigeon Packs, River Crabs). Aggro when hit, leash back if you run, last-hit gold/XP/CS, nearby allies get a little XP, then respawn. Fog applies. `JungleService`. Practice bot clears are described under **Practice bots** (Easy none, Normal nearest-when-pushed, Hard route then rotate).
- **Scoreboard:** hold Tab. Client overlay on the match snapshot (includes `cs`).
- **Match end:** nexus HP → 0 stops minion/jungle/tower/vision ticks, clears combat (including recall/death timers), and shows Victory/Defeat + team KDA + MVP + post/stall/core counts and a match-lifetime structure timeline. **Ended counts as busy** so queue/practice cannot start underneath the screen. **Back to lobby** (`LeaveMatch`) or **Practice again** (`PlayAgain`) skip the 45s timer; the timer still auto-returns so nobody soft-locks. Kitty Caster + kill-feed announce “Enemy nexus destroyed!” (per-team Victory/Defeat).
- **Minimap:** client paints the server fog mask (unexplored / explored-but-unseen / currently seen); click-to-ping is team-only (`PingReceived`). Unseen enemies never get a dot. Explored tint survives leaving vision and mid-match reconnect.
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

**This scaffold models a purchase-linked entitlement that could result in an off-platform mint.** Moving the signing operation off Roblox does not establish permission for the economic flow. The current provider is mock; production review must cover the complete purchase-to-mint relationship, not only private-key placement. See [pairing boundaries and outstanding decisions](docs/robinhood-chain-pairing.md).

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

**Swap for real assets:** upload to Creator Store → copy the numeric id → set `id = "rbxassetid://YOUR_ID"` on that cue. Tweak `volume` / `playbackSpeed` in the same table. Mute and master volume go through `SoundService.MeoSfx` (`SoundGroup`). Slider + mute values (and last Practice difficulty) persist in DataStore `MeoSettings_v1` (Studio memory fallback) and sit on the player as `MeoSfxVolume` / `MeoSfxMuted` / `MeoMusicVolume` / `MeoMusicMuted` / `MeoMuteOthersEmotes` / `MeoPracticeDifficulty`.

### Music beds

`src/client/Audio/Music.luau` loops a quiet bed per match phase and **crossfades ~1s** (no hard cuts). Default Music master is **0.35** (SFX is 0.8). Group: `SoundService.MeoMusic`. Slider: `MeoMusicVolume` / `MeoMusicMuted` (loaded via `GetSettings` before the first `Music.setPhase` when remotes are ready).

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

Each locked cat gets a **distinct silhouette** built from engine `Part`s — body tint, ears, tail, team collar, plus archetype flair (antenna / visor / hat / hood / cape / blades / aura). Closet drip lives in a sibling `MeoCosmetics` folder (also Parts, `MeoLook` so looks rebuilds do not recolor them). No mesh binaries in git.

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
| Line skillshot | Pooled neon bolt travels origin→dest; burst at the end |
| Ground / instant AoE | Expanding ring (after click-to-confirm) |
| Dash | Streak along the path |
| Heal / shield | Soft burst; shield also gets a ForceField bubble (~1.1s) |
| Auto-attack | Claw flash + hit spark (spark debounced ~140ms) |
| Tower / nexus shot | Team-colored bolt (lantern stalls shoot warm gold) |
| Structure death | Puff of neon balls |
| Stun | Three stars orbit the head for the stun duration |
| Recall | Mint cylinder under feet for the 7s channel |

Aim indicators (`TargetingIndicator`) stay client-predicted while a line/dash is held or a ground AoE is armed. World FX spawn only after the server confirms the cast or projectile tick. Combat numbers stay server-authoritative.

## Meme stocks (side system)

`src/server/Economy/MemeStockService.luau` keeps server-authored champion tickers and a **yarn** wallet. Prices wander; kills bump the killer’s cat. The top HUD tape is cosmetic for now (`CheerTicker` remote exists for later shop/wager UI). Turn it off with `Config.Economy.Enabled = false`.

## Project layout

```
PLAYTEST.md          Studio / publish walkthrough + keybind sheet
src/shared/          Types, remotes, constants, mode catalog, yarn-run catalog, koi catalog, yarn-party catalog, arcade catalog, yarn daily-board logic, cosmetic catalog, champion catalog, champion looks, item catalog, progression, targeting, projectile travel, **recall cancel rules**, **vision/fog grid**, emote catalog, ping catalog
src/server/
  init.server.luau   Wires remotes + services
  Config.luau        Tunables + AI / Meo404 product placeholders
  Mode/              Per-player Hub / Moba / YarnRun / KoiPond / YarnParty / MemeArcade gate
  Cosmetics/         Closet DataStore + Part hats/trails applied on any player character
  YarnRun/           Authoritative 3-lane dash + night-market track Parts + daily/weekly boards + persisted PB ghost
  KoiPond/           Authoritative fishing + UTC daily catch board + night-market canal Parts
  YarnParty/         Authoritative 4-cat micro-rounds + courtyard Parts + bots
  Arcade/            Authoritative yarn-tape stall + UTC daily profit board (isolated from in-match meme stocks)
  Match/             Matchmaking, reserved-server teleport, match lifecycle, combat, minions, jungle, towers, vision, wards, shop, practice bots
  Voice/             VoiceChatService wrapper
  World/             3-lane map (art pass + lighting), cat NPC placeholders, champion appearance builder, FX relay
  Npcs/              Catalog, mock/http AI, chat service
  Economy/           Optional meme stocks
  Mint/              ProcessReceipt, DataStore entitlements, SIWE challenge/verify, claim API stub, Studio GrantProduct/ReplayReceipt
  Tutorial/          First-Practice tip dismiss flag (DataStore + memory fallback)
  Settings/          Audio + Hide my name + Practice-difficulty prefs (DataStore `MeoSettings_v1` + memory fallback)
  Social/            Emote cooldown + nearby replicate
src/client/          HUD, hub grid, lobby, Closet wardrobe, Yarn Run HUD/camera/ghost/daily+weekly board, Koi Pond HUD/camera/daily board, Yarn Party HUD/camera, Meme Arcade HUD/camera/daily board, draft, abilities, kill feed, scoreboard, end screen, minimap, targeting indicator, camera, voice, NPC chat, Audio/, Juice/ (screen + world CombatFx + **fog overlay** + emote billboards)
contracts/           Meo404.sol + Foundry tests
bridge/              Hosted claim-handler + SIWE challenge/verify stub (viem)
```

Authority rule: money, prices, damage, match state, and purchase entitlements live on the server. Chain keys never do.

## Next suggested steps

1. More Yarn Party micro-round types. Optional weekly Koi/Arcade boards. Live name refresh for players whose settings are not cached on this server (today they keep the last submitted anon flag).
2. Smarter bots: dive / dodge / lens / projectile lead and a Hard camp route (finish, then rotate) are in. Next: hold skillshots until the lead is clean, tower-dive with more allies.
3. Mesh LoS is in (eye-height walls + thick cover, mesh raycast on `MeoBlocksVision`). Inner lantern stalls grant the existing tower vision radius.
4. Replace placeholder SoundIds / emote cues / `MusicIds` beds with original meows and real loops. Uploaded emote poses instead of Part bob.
5. Surrender vote + explicit “leave champ select” without tearing down a 5v5. Danger ping on low-HP allies; ping wheel on minimap right-click.
6. Richer post-match (damage graph, CS timeline). The end screen already lists post/stall/core counts and the structure fall order.
7. Swap placeholder Part silhouettes / map kits for uploaded meshes (keep `HumanoidRootPart` and `MapBounds`). Closet drip stays Parts-only unless you hang accessories on the same `MeoCosmetics` welds.
8. Publish `MatchPlaceId` and playtest live reserved teleports; `GetChatGroupsAsync` so voice-eligible cats land together.
9. Accept/decline party invites, cross-server friends, party chat in lobby. Custom voice: push-to-talk, per-player mute.
10. Swap the HTTP stub for a hosted proxy so API keys never sit in the place file.
11. More closet slots (back / emote-only) funded by yarn / meme-stock wagers — still no Robux cosmetic shop unless legal review says otherwise.
12. Open Cloud re-verify of DataStore entitlements from the bridge; persist SIWE nonces / verified wallets beyond one process.
13. Compliance / legal review before any live Developer Product that mentions 404 / NFTs.

## License / secrets

Do not commit API keys, minter keys, `.env`, or `Secrets.luau`. `.gitignore` already drops Roblox binaries, Rojo sourcemaps, Foundry `out/` + `lib/`, and secret files.
