# Playtest Meo Meo Meo

Step-by-step for running the cat MOBA in **Roblox Studio** or a **published experience**. Source of truth is this Rojo tree. In Play, press **?** or hold **H** for the same keybinds.

Do not commit API keys, `ClaimApiSecret`, or any chain private key.

## 0. What you have

Playable scaffold: **hub grid** (Cat Rift / Yarn Run / Koi Pond / Yarn Party / Meme Arcade) → Cat Rift practice or queue → 14-cat draft → 3-lane fight → end screen → hub. **Yarn Run** dash + daily/weekly board + persisted PB ghost. **Koi Pond** fishing + UTC daily catch board. **Yarn Party** 4-cat micro-rounds (lobby seats, bots hold empties, friends take a seat before GO). **Meme Arcade** timed yarn-tape stall + UTC daily profit board (play yarn only). **Audio → Hide my name** lists you as **Anonymous Cat** on those boards.

Also: reserved-server-ready queue (in-place fallback), practice bots (Hard dodge / dive / lens / Pawmart; leads traveling skillshots), **team voice pill** (allow-lists refreshed across draft / fight / end, **Mute me**, Studio stays honest), **Kitty Caster callouts** (first blood, streaks, posts, stalls, yarn core, victory — mock lines, no API key), meme-stock tape, Meo404 DataStore entitlements + mint panel, **Closet drip** (hats + trails, yarn points, DataStore `MeoCloset_v1`), client SFX + juice, distinct champion silhouettes, **traveling line bolts** + click-to-confirm ground AoE, **true fog of war** (server mask + ground overlay + brush + fading last-seen ghosts), map art pass, **first-Practice tip cards** (Next / Skip all; lobby **Show tips**).

This is **not** a finished live-ops title. Placeholders (`0` / `""`) are Studio-safe. Hub **Live** reports which of those are still stubs. It does not block Play. See §7.

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

`selene 0.31.0` against this tree: no parse errors. Pre-existing `if_same_then_else` hits may remain in `MatchService.luau` (same-assignment branches). This slice does not refactor those.

## 2. Sync into Studio

For a standalone place, build from the repo root and open the resulting file in Studio:

```bash
rojo build default.project.json -o MeoMeoMeo.rbxlx
```

Press **Play** to generate the map and host models; these are created by server scripts at runtime. This route does not need an active Rojo connection. Rebuild after source changes. Generated place files are gitignored; commit source changes instead.

Build verification on 2026-09-22: Luau compiled 125 sources; team voice allow-lists and HUD copy (teammates only, bots silent, Studio / live / muted / not eligible, mic armed without a fake speaking pulse) + farm credit (kitten and camp last hits add CS, kill/assist/tower gold does not) + combat projectile + kit hooks (Meow guard/pull, Nyan reset/channel, Whiskers refund/zone, Chonk Settled Loaf/Charge Knock, Scammy Open Wick/Hype Candle, Grandma Second Helping/Sweater Aura, Bytekit Packet Buffer/Overclock, Sir Scratchalot Honor Bleed/Shield Fortify, Shadowpounce Alley Mark/Smoke Vanish, Chromeclaw Chrome Plate/Lunge Reload, Oracle Paws Ward Omen/Foresight Veil, Archmeow Spell Charge/Charged Meteor, Hexkit Curse Stacks/Hex Zone, Mindwhisker Psi Mark/Mind Nudge) + recall cancel-on-order + Control Yarn stacks + Pawmart Yarn Cleave / Stall Fang / Paper Charm + practice-bot Pawmart plans (Hard fountain build, cleave at two visible enemies, lens only when owned) + structure layout/gates (outer posts, inner lantern stalls, yarn-core gate) + vision/fog (mesh LoS: eye-height walls + thick cover, mesh raycast, 10-stud grid, match-lifetime explored OR, last-seen ghost freeze/fade) + jungle-bot route/commit/rotate + brand/lobby + cosmetics/arcade/koi/yarn/party (lobby seat takeover) smokes passed; Rojo 7.4.4 builds the place. This is build verification, not a Studio voice or playtest.

Cat Rift closet (same day, later slice): Luau compiled 125 sources; `tools/test-cosmetics.py` passed (Lantern Cap / Stall Spark / Scratch Tally, win yarn 6 / loss yarn 2, older stall unlocks unchanged). The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to take a post or win for the `UNLOCKED ·` ticker.

Kitty Caster callouts (same day, later slice): Luau compiled 127 sources; `tools/test-announcer.py` passed (first blood, double through penta, 8s ordinary cooldown, lane-kitten quiet unless first blood or an ace on a team of 2+, post / stall / yarn-core lines, victory and defeat cues). The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to hear the lines in Practice.

Smart pings (same day, later slice): Luau compiled 128 sources; `tools/test-ping.py` passed (named Caution / Attack lines, Attention refuse on a fogged enemy, ground and minimap Attention / Missing still allowed, post / stall / core marker shapes, 2s cooldown). The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to ping a bot, a lantern stall, and fogged ground (§8f).

Meme tape (same day, later slice): Luau compiled 130 sources; `tools/test-meme-stock.py` passed (kill up, death down and smaller, post then stall then yarn core, team nudge smaller than a last hit, lane kittens and camps refused, same-kind gap). The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to scratch a bot and a post and watch the tape under the kill feed.

Lobby hosts (same day, later slice): Luau compiled 130 sources; `tools/test-brand.py` passed (Closet / Lantern Cap / Stall Spark, fog and last-seen ghosts, Invite / party queue, Pawmart Yarn Cleave on **7** / Stall Fang / Paper Charm, Kitty Caster, smart pings on **G**, death recap, purse chip, **Mute me**, meme tape as a side system, six topic chips, a rare idle line). The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to talk to MEO, ME, and MO (the live-pass below). No API key.

First-Practice tips (same day, later slice): the deck keeps move, scratch, abilities, the kit cards, recall, wards, and fog, and adds a short tail for the systems shipped after those cards. Purse gold/CS shares the Pawmart card with Yarn Cleave (**7**), Stall Fang, and Paper Charm. One card covers outer post → lantern stall → yarn core. Then death recap, Kitty Caster plus named **G** pings, Invite / party queue, and Closet unlocks plus **Mute me**. Hub **Live** stays on the **H / ?** Tips row, not a card. `MeoTutorial_v1` is still a boolean, so a player who already skipped or finished is not shown the new cards until lobby **Show tips**. See the live-pass under §3.

Verified locally: Luau compiled 133 sources; `tools/test-tutorial.py` passed (17-card deck, **Next** / **Got it**, **Skip all** stays dismissed, **Show tips** replays after a finished flag, live matches and other modes stay quiet, hub **Live** stays on the Tips row). The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to step **Show tips** in Play.

Old Tom jungle coach (same day, later slice): Luau compiled 134 sources; `tools/test-old-tom.py` passed (camp gold and respawn, clear vs rotate, Control Yarn on **6** / Whisker Lens on **5**, fog memory and the 1.8s ghost, Hard pigeon → golem → crabs, five chips, a rare ambient gap). `tools/test-brand.py` still passed. The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to talk to him in Practice (the live-pass below). No API key.

Canal Levi (same day, later slice): one river epic, not a dragon / baron / herald set. It wakes at **3:00**, 1100 HP, in the canal between mid and the south crab. The last hit's team keeps **+8% auto-attack and ability damage** for the rest of the match (the purse chip grows a line; Kitty Caster calls it). It returns **once**, about 90 seconds later, then stays down. A second take on the same side does not stack. The other side can earn its own buff on the return. Fog still hides the living body. The minimap shows a pit marker while it is up in fog, or while it is waiting to return, and a larger body dot only in vision. **Hard mid contests it when UP** — leftover route camps and rotates lose to the canal; a camp they already hurt still finishes first. Low-HP flee and tower panic stay in BotService. A visible enemy on the pit is peeled when in face range. Normal mid may tag along only if already mid-river. Easy ignores it. Verified locally: Luau compiled 136 sources; `tools/test-jungle-bot.py` and `tools/test-combat.py` passed (3:00 wake, one 90s return, non-stacking +8%, pit vs body, Hard Levi priority over leftover camps). `tools/test-announcer.py` and `tools/test-old-tom.py` still passed. The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to fight it and watch Hard mid path (the live-pass below).

Hard mid Levi contest (same day, later slice): raised the JungleBotLogic Canal Levi goal above leftover camps when the body is UP. Hard mid walks and attacks it unless they are finishing a hurt non-epic camp, fleeing low HP, or in tower panic. Visible enemies on the pit get a peel when in face range; after Levi dies the route / rotate resumes. Normal may assist only inside the canal pocket; Easy still ignores. Emotes / aim / kits / shop unchanged. Fog still gates the auto (pit knowledge only). Verified locally: Luau compiled 136 sources; `tools/test-jungle-bot.py` passed (leftover camps lose, engaged camps finish, peel on pit, resume after death, Normal mid-river assist, Easy ignore). Rojo 7.4.4 built the place. Studio live-pass under Canal Levi (Hard Practice, wait for **Levi UP**, watch Red mid).

Structure + Canal Levi HP bars (same day, later slice): client night-market billboards (`Shared.BillboardHp` + `Juice.BillboardHpBars`) read existing `Health` / `MaxHealth` / `Vulnerable` on posts, lantern stalls, the yarn core, and Canal Levi. Bars appear when a structure is damaged or aimed (ally bars stay through fog; enemy bars need vision). Levi shows a clear epic bar while UP and in vision. Cream / amber / coral fill — not the default Roblox humanoid bar. Champion nameplates, lane-kitten labels, bots, kits, and emotes are unchanged. Verified locally: Luau compiled 138 sources; `tools/test-structure.py` passed (gates + HP visibility). Rojo 7.4.4 built the place. Studio live-pass under inner towers (damage a post, see the bar) and Canal Levi (UP bar in vision).

Lane kitten + jungle camp HP bars (same day, later slice): same `BillboardHp` / `BillboardHpBars` pool now paints small team-tinted bars on lane kittens when damaged or aimed (ally through fog; enemy needs vision) and camp bars on pigeon / golem / crab when damaged or in combat (aim or aggro), fogged when the camp is unseen. Canal Levi keeps the epic always-UP-in-vision bar. Soft cap + reuse so a full healthy wave does not spawn unbounded GUIs. Champion nameplates, Pawmart, bots, and kits unchanged. Verified locally: Luau compiled 139 sources; `tools/test-structure.py` passed (kitten / camp visibility + fog). Rojo 7.4.4 built the place. Studio live-pass under kitten/camp HP bars (scratch a wave; fog a camp).

Floating combat numbers (same day, later slice): Practice hits that the local player deals or takes raise a short cream/coral float at the target (mint for heal/shield; Stall Fang execute larger/bolder). Same `CombatFx` remote — `kind = "float"` with amount + kind — not a second combat system. Client merges near-simultaneous hits and soft-caps on-screen pops so Yarn Cleave / AoE does not carpet. Fogged enemy bodies stay quiet. Hub / Yarn Run / Koi / Party / Arcade stay quiet. HP bars, death recap, and kits unchanged. Verified locally: Luau compiled 140 sources; `tools/test-combat.py` passed (CombatFloat format / merge / fog / spam). `tools/test-structure.py` still passed. Rojo 7.4.4 built the place. Studio live-pass under §8c.

Level-up juice (same day, later slice): local Cat Rift level-ups from the existing combat level-change edge get a punchier cream/amber **LEVEL UP** banner + soft amber flash (`ScreenJuice.levelUp`), a brief silhouette neon flash + expanding foot ring + optional floating `LEVEL n` (`CombatFx.localLevelUp`), and an amber ability-bar pulse on the QWER slot that auto-gained a rank (`AbilityBar.flashRanks` via `LevelUpJuice.gainedSlots`). XP curve, minion XP, floating damage, and select UI stay unchanged. Teammate level-ups stay kill-feed only (Kitty Caster still skips level narration). Verified locally: Luau compiled 142 sources; `tools/test-combat.py` passed (LevelUpJuice helpers); full smoke suite passed (24). Rojo 7.4.4 built the place. Studio live-pass under level-up juice (farm a wave).

Ability bar cooldown feedback (same day, later slice): Cat Rift `AbilityBar` keeps the same cooldown seconds and CombatService timings. Each QWER slot and Ward / Lens / Cleave chip gets a translucent ink sweep that shrinks while `readyAt` is in the future, a mint ready flash when the slot hits 0, and a coral mana-gate tint when mana is too low for the next cast (even off cooldown). Control Yarn still shows `×charges`. Overlays are non-Active so they do not eat clicks. Hub / Yarn Run / Koi / Party / Arcade stay unchanged. Floating damage, HP bars, and kits untouched. Verified locally: Luau compiled 140 sources; full smoke suite passed (24). Rojo 7.4.4 built the place. Studio live-pass under ability bar CD.

Yarn Run juice / readability (same day, later slice): stream-readable power chips + soft screen tint for SPD / MAG / SHD / 2X (equal banners + `ScreenJuice.powerFlash`; SHIELD POP keeps its coral pop). CLOSE! / COMBO BREAK pop larger; near-miss adds a cheap `YarnCamera.kick`. Lane neon + outer rails slightly stronger; dogs / DODGE walls get a ground telegraph — seed / scoring / ghost / boards unchanged. Death card shows a one-glance PB compare line and clearer Daily / Weekly rank strip. Cat Rift / Closet / other stalls untouched. Verified locally: Luau compiled 140 sources; `tools/test-yarn.py` passed (power chip RGB / labels, death PB + rank lines). Full smoke suite passed (24). Rojo 7.4.4 built the place. Studio live-pass under §3b Yarn Run juice.

Koi Pond juice / readability (same day, later slice): clearer cast → nibble → cream-window reel feedback without touching wait / bite / window sizes or rarity weights. Bobber **NIBBLE!** + splash; lantern rail pulses with a brighter cream window (**REEL → NOW** when the loaf is inside) plus a cream **REEL THE CREAM** banner. Catch pops use exact fish tints (cream → peach → mint/cobalt → amber → coral) with score + rarity tag; **LEGENDARY KOI** keeps ticker/flash and adds a cheap `KoiCamera.kick` + **CROWN!** fish. Stall log / Best line / **Daily board** (`Canal Daily · Best Catch`) are one-glance clearer. Yarn Run / Cat Rift / Closet / Party / Arcade unchanged. DataStore schema unchanged. Verified locally: Luau compiled 140 sources; `tools/test-koi.py` passed (catchTint / rarityTag). Mode smokes (yarn / party / arcade / brand) still passed. Rojo 7.4.4 built the place. Studio live-pass under §3c Koi Pond juice.

Meme Arcade juice / readability (same day, later slice): louder **Buy / Sell** confirms (`BOUGHT` / `SOLD` toast + ticker-card flash on **1–5** / **Shift+1–5** and card buttons). **RUG PULL** / **TO THE MOON** / **WHALE SNEEZE** (and settle **BOOM** / **BUST**) get a colored event plate + screen flash; yarn-only disclaimer stays visible. Settle card shows one-glance score (`±yarn · wallet`) and **Daily #** / high strip. Candle bars slightly taller / higher contrast — tape RNG, prices, and event magnitudes unchanged. Isolated from in-match `MemeStockService`. Yarn Run / Koi / Party / Cat Rift / Closet unchanged. Verified locally: Luau compiled 140 sources; `tools/test-arcade.py` passed (tradeToast / settleScoreLine / settleRankLine). Full smoke suite passed (24). Rojo 7.4.4 built the place. Studio live-pass under §3e Meme Arcade juice.

Yarn Party juice / readability (same day, later slice): stream-readable lobby countdown (**STARTS IN N** pulses) and punchier seat rows (`[YOU]` / `[CAT]` / `[BOT]` chips). Giant round titles keep a short rule banner (Dodge hop / Stall Freeze lit pillow). Elim pops (`YARN BONK` / `WRONG PILLOW`) get a coral event plate + banner + cheap `YarnPartyCamera.kick`. **CROWNED** podium highlights the winner and keeps **Party again** / **Back to hub** obvious. Join polish / scoring math / three mini-rounds / other hub modes unchanged. Verified locally: Luau compiled 140 sources; `tools/test-party.py` passed (ruleBanner / seatLine / isElimPop / podium lines). Full smoke suite passed (24). Rojo 7.4.4 built the place. Studio live-pass under §3d Yarn Party juice.

Closet wardrobe juice / readability (same day, later slice): Closet rows get rarity chips (`CMN` / `UNC` / `RARE` / `EPIC`) and unlock-source chips (`STARTER` / `YARN` / `RUN` / `KOI` / `PARTY` / `ARCADE` / `RIFT`) so locked drip is not hint-text-only. Equipped rows show **✓** / **ON** / **Worn ✓**; locked rows dim with **LOCK**. Hover try-on ghosts locked slots and paints owned drip on the silhouette. `EQUIPPED ·` / `UNLOCKED ·` / `BOUGHT ·` get louder ticker + banner + `ScreenJuice.powerFlash` plus a preview-frame flash and a brief avatar `MeoCosmetics` neon pulse. Emote flair (#68) unchanged. Unlock thresholds, Gold Bell 25 yarn, start 40 yarn, and `MeoCloset_v1` schema unchanged. Other stalls untouched aside from shared ScreenJuice. Verified locally: Luau compiled 141 sources; `tools/test-cosmetics.py` passed (rarityTag / unlockSource / toastTint + gate amounts). Full smoke suite passed (24). Rojo 7.4.4 built the place. Studio live-pass under §3f Closet wardrobe juice.

Hub mode-grid polish (same day, later slice): night-market discover grid — punchier stall titles + one-line blurbs, per-stall wash / accent / glow (coral yarn, canal mint, neon arcade), stronger hover + selected chrome, soft rate-limited idle bob. **Closet**, **Live**, Mint, Audio, and Meet the cats stay reachable; tagline keeps **meo meo meo** / shared braincell. ModeCatalog display helpers (`stallTag` / `oneLine` / `playLabel` / `glowAccent`) — playable flags unchanged. Mode gameplay and Closet unlocks untouched. Verified locally: Luau compiled 141 sources; `tools/test-brand.py` passed (display helpers, hover stroke lift, Closet / Live). Full smoke suite passed (24). Rojo 7.4.4 built the place. Studio live-pass under hub grid polish.

Champion select kit teasers (same day, later slice): Cat Rift draft cards stay name / role / look / blurb / swatch, and add a two-line kit teaser (`passive · signature` from `ChampionKits.teaser` / `teaserLine`) so all 14 cats read at a glance before lock-in. Taller scroll grid, optional role chips (All / Tank / Bruiser / Assassin / Mage / Marksman / Support), clearer **LOCKED** amber stroke + **TAKEN** dim for same-team dupes, coral title urgency under 10s. Pick rules and combat kits unchanged — select UI only reads kit labels. Verified locally: Luau compiled 141 sources; `tools/test-combat.py` passed (flagship + expansion teasers). Full smoke suite passed (24). Rojo 7.4.4 built the place. Studio live-pass under champion select.

Match end screen polish (same day, later slice): punchier **VICTORY** (mint/amber plate + soft ScreenJuice sting) vs **DEFEAT** (coral). MVP gets a **CROWN** chip; your row is amber-washed with a **YOU** mark. Structure timeline splits **Posts → Stalls → Core**, and names a Canal Levi take from existing `riverEpic` buff flags (no new remotes). Buttons: **Practice again** / **Back to lobby** / **Hub**. Match stats math, MVP pick, and Kitty Caster end lines unchanged aside from display. Verified locally: Luau compiled 143 sources; `tools/test-end-screen.py` passed; full smoke suite passed (25). Rojo 7.4.4 built the place. Studio live-pass under match end screen.

Cat Rift resource bars (same day, later slice): AbilityBar HP / mana / XP paints stay on the existing combat + XP snapshot fields (no regen or max changes). Coral HP and cobalt mana fills show **current / max**; amber XP keeps a **Lv n · into / need** label. HP under 30% warn-pulses; mana-gate on QWER mirrors a coral pulse on the mana track (slot coral tint unchanged). Purse chip and Levi clock stay clear; Hub / Yarn Run / Koi / Party / Arcade have no Cat Rift resource bars. End screen / level-up juice unchanged aside from shared bottom layout spacing. Verified locally: Luau compiled 144 sources; `tools/test-resource-bars.py` passed; full smoke suite passed (26). Rojo 7.4.4 built the place. Studio live-pass under resource bars.

Minimap clarity (same day, later slice): client-only `Shared.MinimapPaint` restyles Cat Rift minimap dots — cream **you** pip with ink ring, ally cream stroke vs enemy coral stroke, posts / open stalls / yarn core match smart-ping shapes, gated stalls read as dim wood lanterns, Canal Levi **UP pit** / **respawn** / **taken** / in-vision **body** are distinct, click Attention flash on the map. Fog mask stays server-authoritative; explored tint stays lighter than unexplored. Resource bars / end screen / hub unchanged. VisionService mask math untouched. Verified locally: Luau compiled 145 sources; `tools/test-minimap.py` passed; `tools/test-vision.py` + `tools/test-ping.py` extended; full smoke suite passed (27). Rojo 7.4.4 built the place. Studio live-pass under minimap clarity.

Kill feed polish (same day, later slice): `KillFeed` rows become night-market chips via `Shared.KillFeedPaint` — peach kills, lantern posts, wood/lantern stalls, pink yarn core, quiet amber Kitty Caster announces, cobalt pings, mint level-ups. Max four rows with age fade; announce chips expire sooner so they do not fight her banner. Your kills / deaths / structure takes get a light cream or coral ring from existing cat copy (no new combat remotes; `stall` FeedKind tags lantern stalls). Meme tape sits just under the stack. Combat scoring and announcer text unchanged aside from presentation. Verified locally: Luau compiled 146 sources; `tools/test-kill-feed.py` passed; full smoke suite passed (28). Rojo 7.4.4 built the place. Studio live-pass under kill feed.

Tab scoreboard polish (same day, later slice): hold-**Tab** mid-fight board reads like the end screen — Blue / Red section headers, amber **YOU** row wash, dead cats dimmed from existing `respawnAt`, bots still tagged `(Bot)`, Items column short-labels + clean ellipsis via `Shared.ScoreboardPaint`. Soft ★ crown on the living kill lead (or `mvpUserId` after the match). Same MatchSnapshot gold / CS / KDA / items — no new remotes. Hold-Tab stays non-modal; kill feed / minimap / resource bars unchanged. Verified locally: Luau compiled 147 sources; `tools/test-scoreboard.py` passed; full smoke suite passed (29). Rojo 7.4.4 built the place. Studio live-pass under Tab scoreboard.

Pawmart clerk shop tips (same day, later slice): `Shared.PawmartGuide` teaches both fountain clerks (`PawmartBlue` / `PawmartRed`) with authored facts and Blue tired-retail / Red upseller asides. Chips: **Shop**, **Actives**, **Wards**, **Builds**, **Help**. Covers **B** fountain-only, start gold 500 / purse CS, Longclaw / Yarnplate / Mana Treat / Pounce Boots, Lens **5** / Control Yarn **6** / Cleave **7**, Stall Fang, Paper Charm, and a Hard bot buy one-liner. Rare Cat Rift ambient on the Talk prompt. Old Tom, hosts, and Kitty Caster unchanged. Mock / HTTP both gate on the guide before generic lines. No API key. Verified locally: Luau compiled 139 sources; `tools/test-pawmart-guide.py` passed; `tools/test-brand.py` and `tools/test-old-tom.py` still passed. Rojo 7.4.4 built the place. Studio live-pass under Pawmart clerks.

Match clock (same day, later slice): Cat Rift InProgress shows a top-left **mm:ss** clock and a Canal Levi line. The server publishes `startedAt` and `riverEpic.nextAt` on the match snapshot. The client only paints: a countdown from **Levi 3:00** (`Levi 1:24` on the way), **Levi UP** while it is alive, **Levi 0:47** for the one return, **Levi taken** after the second death. The purse chip still uses **Canal Levi · +8% damage**, and names the other side on that same line when they hold the buff. The minimap pit marker stays. Kitty Caster's take line stays. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show the clock. Verified locally: Luau compiled 136 sources; `tools/test-combat.py` and `tools/test-jungle-bot.py` passed (mm:ss, countdown, UP, respawn, taken, purse holder line). `tools/test-announcer.py` still passed with the take line unchanged. The other mode smokes still passed. Rojo 7.4.4 built the place. Studio still has to watch the countdown, the wake, the take, and the respawn timer (the live-pass below).

Ability aim indicators (same day, later slice): client-only `TargetingIndicator` juice. Thin ForceField range ring; line skillshots show width from `radius`; ground AoE a clear circle at the clamped aim point; dash a short streak + tip (not a full bolt). Mint when valid, coral when clamped / out of range. Ground stays armed until click / second press / Esc / RMB / S. Instant heals and shields never leave a ghost ring. Fog still hides enemies — indicators do not reveal them. Kitty Caster, Canal Levi, and kit numbers are unchanged. Verified locally: Luau compiled 136 sources; `tools/test-combat.py` passed (Targeting.preview clamp / warn / instant hide). Rojo 7.4.4 built the place. Studio still has to hold Q, confirm a ground cast, and Esc-cancel (the live-pass below).

Emote wheel + Closet flair (same day, later slice): hold **T** wheel gets clearer wedge highlight, release-to-cast, and **Esc** cancel. Server attaches Closet `emoteFlair` tint on `EmotePlayed`; EmoteFx paints a larger bob, stroke, and sparkle when Moon Dust / Canal Crown / Braincell Orbs / Stall Spark is equipped. Nearby hub + mode players still see the billboard (foes in Cat Rift too); cooldown stays ~2.6s. **G** pings unchanged outside the Rift. Combat / Levi / aim indicators untouched. Verified locally: Luau compiled 136 sources; `tools/test-emote.py` and `tools/test-cosmetics.py` passed. Rojo 7.4.4 built the place. Studio live-pass under §8e.

### Lobby host acceptance check

1. Start Play and check the **hub grid** title (**meo meo meo**) plus Cat Rift's **Three lanes. One shared braincell.**
2. Walk toward the three hosts near the lobby spawn. Confirm orange MEO, ivory ME and charcoal MO each show a name and **Talk** prompt. Check the eyes and cobalt forehead square from the front.
3. Talk to each host. Confirm the dialogue panel names the selected host and replies in that host's voice. Hosts should not block movement.
   - Each host opens with a distinct authored greeting. Switch hosts while a reply is pending: the new conversation should contain only the new host's greeting and subsequent messages. Closing and reopening the same host should also discard pending replies from the old conversation.
   - Send with both Enter and the Send button. If a request fails, the panel should offer a retry message. The transcript keeps the most recent 60 lines per open conversation.
   - Hosts show six chips: **Cat Rift**, **Closet**, **Fog**, **Shop**, **Voice**, **Help**. Tapping a chip asks that question and leaves any unfinished draft in the box. Kitty Caster stays chipless. Old Tom has his own row (**Camps**, **Wards**, **Fog**, **Route**, **Help**) — see his live-pass. Fountain clerks have **Shop**, **Actives**, **Wards**, **Builds**, **Help** — see the Pawmart clerk live-pass.
   - Stand near a host without pressing **Talk**. Once in a while a short line appears over that cat and then leaves. Walking the trio should not stack three speeches. Opening **Talk** clears the line. The hosts still do not block movement.
4. With two Studio clients, queue both players and confirm live queue status stays readable and the match starts. The host answer for **Invite** matches what this queue actually does.

### Studio live-pass (lobby hosts)

The Luau smoke checks authored replies, chip questions, and the idle-line gap. It does not move a character and it does not call an LLM. Talk to the three hosts in Play. No OpenAI key.

1. Open **Talk** on MEO, then ME, then MO. The chips match. **Help** lists Cat Rift, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade. **Cat Rift** still says to use that stall's **Play** button. MEO can sound sure of himself. The controls below stay the same on every host. ME stays practical. MO stays soft. None of them name a PlaceId, a Robux price, or an investment.
2. **Closet** (or type "Lantern Cap" / "Stall Spark"). Hub **Closet**. Yarn points, not Robux. Lantern Cap after an outer post or a lantern stall. Stall Spark after a Cat Rift win. A win pays 6 closet yarn and a loss pays 2.
3. **Fog**. Unseen ground stays dark, explored ground stays dim, walls and thick cover block sight, brush hides you until someone walks in. A last-seen ghost freezes and fades. It is not vision. It is not the Yarn Run personal-best cat.
4. Type "invite" or "party queue". Same-server **Invite**, **Accept** or **Decline**, about 20 seconds. The leader presses **Queue party** or **Practice with party**. Practice stays in this server. "Yarn Party" on its own is still the party stall, not this queue.
5. **Shop** (or "Yarn Cleave" / "Stall Fang" / "Paper Charm"). **B** at the fountain. Yarn Cleave is 280 gold, then **7**. Stall Fang is 300 gold and bites champions at or below 20% HP. Paper Charm is 220 gold: about 2.4 seconds after an enemy pink, then about 20 seconds. **5** is still Whisker Lens. **6** is still Control Yarn.
6. Type "Kitty Caster". First blood, streaks, posts, stalls, the yarn core, victory or defeat. Lane kittens stay quiet unless that death is first blood or an ace. Talking to her in the river is still mock chat.
7. Type "ping" or "smart ping". **Hold G**. A hidden cat is refused. Fogged ground and the minimap can still ping without a name. About 2 seconds between pings.
8. Type "death recap". Scratches from about the last 12 seconds. The killing blow is marked. The card hides about 2.5 seconds before the fountain. **Recap** brings it back while you are down. The other stalls do not show it.
9. Type "purse" or "cs". The chip above the ability bar is gold, CS, level, and the Yarn Cleave line. **Tab** matches the gold and CS. A kill, an assist, or tower gold does not add CS.
10. **Voice** (or "Mute me"). Teammates only. Bots are silent. **Mute me** is the mic, not SFX or Music. The hub stays quiet until a match assigns a side. Studio blocks voice until you publish and use two eligible clients.
11. Type "meme tape". It sits under the kill feed in Cat Rift only. Play yarn, not gold, not closet yarn, and not the Meme Arcade board. Kittens and camps do not move it. Nothing on it spends Robux.
12. Start a Practice match and confirm the full 14-champion draft still appears. Return to the lobby after a match and check the host prompts again. Fog, callouts, the purse, and the tape behave as in their own passes. The hosts did not become champions.

Smoke (not a Studio substitute): `python3 tools/test-brand.py /path/to/luau`.

### Studio live-pass (Old Tom)

The Luau smoke checks authored replies, the five chips, the mock fallback, and the ambient gap. It does not move a character and it does not call an LLM. Talk to him in Play. No OpenAI key. He stands in the blue jungle, just east of the NW Yarn Golem — not on the fountain pad. Walk there from your fountain.

1. **Hard** Practice (Normal or Easy still answers; Hard is the route he describes). After lock-in, walk from the blue fountain to Old Tom and press **Talk**. The panel greets you as kitten. Chips read **Camps**, **Wards**, **Fog**, **Route**, **Help**. A draft you already typed stays in the box.
2. **Camps**. The joke comes first. Then Pigeon Pack is 22 gold and about 32 seconds, Yarn Golem is 48 gold and about 45, a river crab is 36 gold and about 50, and the last hit adds 1 CS. Clear your own side once the wave is past the river. Finish a hurt camp (Hard under about 40% HP, Normal under about 55%). A healthy camp can wait if a cat is in your face (about 32 studs on Hard, about 22 on Normal). Drag one past about 38 studs and it resets. Then rotate to the pushed lane. Do not pace the river. He also names **Canal Levi**: about 3 minutes in, 140 gold, back once about 90 seconds later, and the last hit's team keeps +8% damage.
3. **Wards**. **4** is the free stealthed trinket, one live, about 70 seconds, lasting about 60. Control Yarn is 75 gold with **B**, two charges, then **6**: a magenta pink everyone can see, about 90 seconds, slowing enemies inside about 22 studs and revealing nearby enemy trinkets. Whisker Lens is 180 gold, then **5**: 80 damage inside about 32 studs (a trinket at 60 pops, a full pink at 90 does not), then about 75 seconds. Your pink slows enemies, not you. Paper Charm shrugs an enemy pink for about 2.4 seconds, then waits about 20. Hard bots drop one free pink and do not buy Control Yarn.
4. **Fog**. Unseen ground stays dark. Explored ground stays a dim tint for this match only. Walls and the thick drums block sight. Brush hides you until someone steps into that same pocket, and you cannot scratch a cat you cannot see. A last-seen ghost fades in about 1.8 seconds. It is not vision, and it is not the Yarn Run personal-best cat. Ward the river before you face-check the crab brush.
5. **Route**. Only mid jungles on Hard. Top and bot stay in lane. Blue: pigeon pack NW → yarn golem NW → north river crab → south river crab. Red (the Practice bots): pigeon pack SE → yarn golem SE → south river crab → north river crab. They hold the camp and do not flip crabs. On a healthy camp they turn inside about 32 studs; under about 40% HP they finish first. Camps pop about 8 seconds in. After the four are down they rotate to the lane where the allied wave is furthest up. A sighting from about the last 8 seconds can pull that. They will not path into brush just because a ghost stood there. Easy never clears. Normal mid takes the nearest own-side camp only after the wave is past the river. When **Canal Levi** is UP, Hard mid contests it over leftover camps and rotates (they still finish a camp they already hurt). Normal may tag along only if already mid-river. Easy ignores it.
6. **Help**, or "camps and wards" together, lists the four topics and does not dump every number. "hello" still gets a short mock line that echoes your words. Kitty Caster stays on that generic mock, with no coach chips. Fountain clerks keep their own shop chips (see the Pawmart clerk live-pass). Host chips are unchanged.
7. Stand in his **Talk** prompt without pressing it, during the live fight (walking up from the fountain counts). Most approaches stay quiet. About one in four, and not twice inside about 75 seconds, a short line appears over him and then leaves. It does not enter the kill feed, and it does not play in the hub, during draft, or in Yarn Run, Koi Pond, Yarn Party, or Meme Arcade. Opening **Talk** clears it. He does not call first blood or towers.
8. Closet, voice, fog rendering, Kitty Caster's callouts, and combat behave as in their own passes.

Smoke (not a Studio substitute): `python3 tools/test-old-tom.py /path/to/luau`.

### Studio live-pass (Pawmart clerks)

The Luau smoke checks authored replies for both fountain clerks, the five chips, Blue vs Red asides, the mock fallback, and the ambient gap. It does not move a character and it does not call an LLM. Talk to a clerk in Play. No OpenAI key. Blue stands at the blue fountain; Red at the red fountain.

1. **Practice** (any bot difficulty). After lock-in, walk to your fountain clerk and press **Talk**. Blue opens tired and receipt-minded. Red opens as an upseller. Chips read **Shop**, **Actives**, **Wards**, **Builds**, **Help**. A draft you already typed stays in the box.
2. **Shop**. **B** opens Pawmart at the fountain only. Recall is still **F**. Start gold is 500. The purse chip and **Tab** show gold and CS. Lane-kitten and camp last hits add 1 CS; kill / assist / tower gold do not. Blue stamps a receipt aside. Red says the register does not take Robux.
3. **Actives**. Whisker Lens 180g then **5**. Control Yarn 75g, two charges, then **6**. Yarn Cleave 280g then **7** (12-stud slash, 40 damage, 12s). Prices and keys stay the same on both clerks; only the aside changes.
4. **Wards**. Free trinket on **4**. Pink vision / slow numbers, Paper Charm 220g (about 2.4s then about 20s), Hard bots drop one free pink and do not buy Control Yarn.
5. **Builds**. Longclaw 250 / Yarnplate 250 / Mana Treat 200 / Pounce Boots 200 / Stall Fang 300, plus the Hard opening fountain role plan one-liner. No fake investments.
6. **Help**, or two topics at once, lists the four and does not dump every price. "hello" still gets a short mock line that echoes your words. Old Tom, the hosts, and Kitty Caster keep their own chips or chipless mock.
7. Stand in a clerk **Talk** prompt without pressing it during Cat Rift. Most approaches stay quiet. About one in four, and not twice inside about 70 seconds, a short line appears over that clerk and then leaves. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade stay quiet. Opening **Talk** clears it.
8. Buying with **B**, fog, Old Tom, and Kitty Caster callouts behave as in their own passes.

Smoke (not a Studio substitute): `python3 tools/test-pawmart-guide.py /path/to/luau`.

### Live sync

From the repo root:

```bash
rojo serve
```

1. Studio → **New place** (or an existing unpublished place).
2. Rojo plugin → **Connect** to `localhost` (default port 34872).
3. Confirm `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and `StarterPlayer.StarterPlayerScripts.Client` appeared.
4. **Play** (F5). Character loads on the night-market pad with the **hub grid** (Cat Rift / Yarn Run / Koi Pond / Yarn Party / Meme Arcade). Title reads **meo meo meo**; subtitle keeps **Three cats. One shared braincell.** Each stall shows a tag chip, punchy title, one-line blurb, and per-stall night-market tint. Hover a tile — stroke glows and the card lifts a touch. **Closet**, **Live**, Mint, and Meet the cats stay on chrome. Audio stays on the top-right settings control.

`*.rbxl` is gitignored. Do not treat a Studio file as source of truth.

| Disk | Roblox |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

### Studio live-pass (hub grid polish)

The Luau brand smoke checks ModeCatalog display helpers, per-stall wash, tag chips, blurbs, Closet / Live chrome, and hover stroke lift. It does not move a character. Do this in Play.

1. **Play** on the night-market pad. Hub title is **meo meo meo**. Subtitle keeps **Three cats. One shared braincell.** Hint mentions hover, Live, Closet, Audio.
2. Confirm five stalls — Cat Rift / Yarn Run / Koi Pond / Yarn Party / Meme Arcade — each with a tag chip, clear title, one-line blurb, and a distinct night-market tint (amber rift, coral yarn, canal mint, party pink, neon tape). Soft idle bob is gentle, not distracting.
3. Hover each tile. Stroke should glow brighter and the card lifts slightly; leave restores rest chrome. Play CTAs and Board buttons still work.
4. Open **Closet** (wardrobe), then close. Open **Live** (publish readiness checklist), then close. Mint and Meet the cats stay reachable. Audio stays on the top-right settings control — do not hide Live.
5. Enter Cat Rift or any other stall via **Play**, then **← Hub** / **Back to hub**. Grid polish returns; mode gameplay feels unchanged.

Smoke (not a Studio substitute): `python3 tools/test-brand.py /path/to/luau`.

### Studio live-pass (champion select)

Draft UI only. Combat kits, pick rules, and hub stalls stay as they were. The Luau combat smoke names flagship + expansion kit teasers (`Golden Parachute · Executive Order`, `Encore · Hyperbeam`, `Office Hours · Pop Quiz`, and the identity pairs). It does not open the draft panel. Do this in Play.

1. Hub → **Cat Rift → Play** → **Practice match**. Draft opens with a scrollable grid of all **14** cats. Each card still shows name, role · look, blurb, and color swatch, plus a kit teaser line (`passive · signature`) under the blurb — hover a few (Meow, Nyan, Whiskers, Chonk, Hexkit) and confirm the labels match the kit passes without dumping full guides.
2. Tap role chips (**All** / **Tank** / **Bruiser** / **Assassin** / **Mage** / **Marksman** / **Support**). The grid filters; **All** restores every cat. Scroll still works when the filter leaves more than one row.
3. Lock a cat. That card gets a thick amber stroke and a **LOCKED** mint tag. If you re-open Practice with bots that already locked (or lock then try another same-team pick in a multi-client draft), **TAKEN** cards dim and refuse a click — same-team dupe block still holds.
4. Watch the title timer. Under about **10s** it turns coral and the hint adds **Lock soon!** Combat after lock-in is unchanged.

Smoke (not a Studio substitute): `python3 tools/test-combat.py /path/to/luau`.

## 3. First session — Practice (solo)

1. Hub → **Cat Rift → Play** → bot difficulty **Easy**, **Normal**, or **Hard** → **Practice match**. On the hub grid first: hover the Cat Rift stall (glow + lift), confirm the one-line blurb, then **Play**. **← Hub** returns to the grid. After lock-in, a cream/coral **tip card** (top-left) walks move, scratch, abilities, the kit cards, **purse + Pawmart** (Yarn Cleave on **7**, Stall Fang, Paper Charm), recall, wards, fog, **outer post → lantern stall → yarn core**, death recap, Kitty Caster + named **G** pings, Invite / party queue, then Closet (Lantern Cap / Stall Spark) and **Mute me**. **Next** or **Skip all**. Combat still works — the card is not a modal. Lobby **Show tips** replays the current deck anytime. Skip/finish persists (`MeoTutorial_v1` boolean, memory fallback in Studio). Players who already skipped or finished stay dismissed until they press **Show tips**. Hub **Live** is on **H / ?** (Tips row), not a card. Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show the card.
   - **Easy** — slow, panicky, sloppy CS, 0.88× damage. Leaves the fountain naked. A later fountain visit buys at most one **Mana Treat**. No dodge; will not dive towers. Does not take jungle camps.
   - **Normal** — last-hits, leads traveling skillshots (72 studs/s), sidesteps incoming bolts/AoEs (hang uses travel time), dives only with a crashing wave or a short low-HP chase. Leaves naked; a fountain return buys two stat items (bruiser: Yarnplate then boots, assassin: Longclaw then boots, mage: Mana Treat then Longclaw). Mid, once the allied wave is past the river, clears the nearest own-side camp and finishes it. A champion in their face can pull a healthy camp; a hurt camp is finished anyway.
   - **Hard** — faster, 1.22× damage, tighter CS, a short role build bought at the opening fountain (bruiser/tank: Yarnplate + Paper Charm, assassin: Longclaw + Pounce Boots, mage: Mana Treat + Longclaw). Stall Fang, Yarn Cleave, and Whisker Lens wait until a later visit can pay for the next one. One early **magenta control (pink)** ward once they have left the fountain (still free — they do not buy Control Yarn). Presses **7** when two visible enemy cats are inside the cleave circle. Uses Whisker Lens when an enemy pink or trinket is inside the lens radius, and only after they own it. Kill-dives. Mid runs pigeon pack → yarn golem → near river crab → far river crab, then rotates to the pushed lane. Top and bot stay in lane.
2. You are Blue Whiskers vs **3 Red (Bot)** cats. Draft a cat (Professor Whiskers / Bytekit / Nyan Rocket are easy to read). Cards show a color swatch + ears, a short blurb, and a kit teaser (`passive · signature`). Role chips filter the 14-cat scroll. After lock-in, you and the Red bots should have **distinct silhouettes** (ears/tail/archetype flair) and nameplates (`Champion · role`, bots keep `(Bot)`). The rift should read as a night-market: gold lane dots, indigo river, fountain lanterns, tower ears / yarn, **lantern stalls** (awning + paper lanterns) between the posts and each keep, jungle camp pedestals. **Fog of war** darkens ground outside ally vision. Your fountain, nearby living towers, and ally minions light bubbles. Red bots in river/jungle stay hidden until they walk into a bubble. When one walks back out, a faint ghost lingers at the last spot, then fades.
3. Walk a lane. Unseen ground stays dark; the minimap matches (no enemy dots in fog). Walk back: cells you already lit stay a lighter **explored-but-unseen** tint (not full black). **LMB** a bot or minion — claw flash + hit spark. You cannot AA a target you cannot see. Hold **Q** if the kit is a line skillshot (thin mint range ring + width from the kit radius; coral when the cursor is past max range), **release** to fire a **traveling bolt** (hits on contact, server-authoritative; client VFX follows — bolts are not clipped by the ground fog overlay). Ground AoEs (Paw Slam etc.): **first press** shows the range ring and a clear aim circle at the clamped cursor, **click or press again** to confirm; **Esc / right-click** cancels and clears the ring. Instant heals still fire on press with **no lingering ghost ring**. Dashes stay hold-to-aim with a short streak + tip (not a full line bolt). Aim juice is local only — it does not reveal fogged enemies. The first-Practice cards include **Three flagship kits** (Meow guard + pull, Nyan reset + breakable beam, Whiskers mana refund + ticking zone), **Three more original kits** (Chonk Settled Loaf + Charge Knock, Scammy Open Wick + Hype Candle, Grandma Second Helping + Sweater Aura), **Three expansion kits** (Bytekit Packet Buffer + Overclock, Sir Scratchalot Honor Bleed + Shield Fortify, Shadowpounce Alley Mark + Smoke Vanish), **Three more expansion kits** (Chromeclaw Chrome Plate + Lunge Reload, Oracle Paws Ward Omen + Foresight Veil, Archmeow Spell Charge + Charged Meteor), and **Last two expansion kits** (Hexkit Curse Stacks + Hex Zone, Mindwhisker Psi Mark + Mind Nudge). Draft blurbs and **H / ?** repeat the short versions.
4. **4** drop a stealthed team-tinted trinket — the pocket it covers should **light up** for your team (and stay dark for Red). Walk a jungle **brush** pocket (NW/NE/SE/SW or river-crab): you vanish from enemies until they enter. **B** at fountain → buy **Control Yarn** (up to 2) → **6** plants a magenta pink ball (visible to everyone, slows, reveals nearby enemy trinkets, grants team vision). Buy **Whisker Lens** → **5** if you see an enemy ward. The same register sells **Yarn Cleave** (7), **Stall Fang**, and **Paper Charm**. On **Hard**, the Red mid jungler may also plant a free pink. See the Pawmart live-pass below.
5. **F** recall (7s) — mint circle under your feet. Stand still and it finishes. A **new** WASD press, a **ground click**, attack, attack-move, a cast, or **7** (Yarn Cleave) cancels immediately and the circle and channel bar disappear. A direction you were already holding does not cancel until you release and press again. Damage still cancels. **B**, **T**, **G**, **H**, and **V** do not. A **purse chip** (above the ability bar) shows your gold, CS, and level. **Hold Tab** scoreboard (Blue/Red sections, **YOU** highlight, dead dimmed, bots tagged, short items) uses the same numbers — see the Tab scoreboard live-pass.
6. Die to a bot or a scratching post. A **Death recap** card lists the recent scratches (cat, post, kitten, camp, or item; ability or **Scratch** when the server knows; approximate damage; killing blow marked). **✕** dismisses it, or it hides about 2.5s before the fountain timer. **Recap** brings it back while you are down. Kill feed and **Tab** stay. The card does not appear in Hub, Yarn Run, Koi, Party, or Arcade.
7. Push one lane **outer scratching post → inner lantern stall → yarn core**. The stall billboard stays `(gated)` and takes no damage until that lane's post falls (death puff + kill feed). Stall shots are warm lantern gold and use the same aggro as posts. The nexus stays `(gated)` until all **3 posts and 3 stalls** are down, then `(OPEN)`. Scratch the nexus. Kitty Caster names the post, the stall, the open yarn core, and the unplug (see the callout live-pass).
8. End screen shows a punchy **VICTORY** (mint/amber) or **DEFEAT** (coral) banner with a soft screen sting, a **CROWN** MVP chip, post/stall/core counts, a **Posts → Stalls → Core** timeline (plus **Levi ·** take when someone held Canal Levi), and a KDA table where **your row** is highlighted. Kitty Caster still stings the kill feed (**VICTORY** / **DEFEAT**). **Practice again**, **Back to lobby** (Cat Rift stall), or **Hub** (night-market grid). Fog overlay and any last-seen ghosts should vanish. Open **Yarn Run / Koi / Party / Arcade / Closet** and confirm hub stalls never paint rift fog, never play rift callouts, and never show the rift meme tape. Last-hitting a post or stall, or winning, can ticker `UNLOCKED ·` for Closet drip (see §3f).

### Studio live-pass (match end screen)

UI only. MatchService scoring, MVP pick, and Kitty Caster end lines stay as they were. The Luau end-screen smoke checks banner copy, timeline order, Levi take lines, and row marks. It does not finish a match. Do this in Play.

1. Hub → **Cat Rift → Practice** (Easy is fine). Push a lane to the yarn core and win, or let Red unplug yours.
2. On **VICTORY**: mint/amber banner plate, soft mint→amber flash once, subline names the winner and the unplugged core. On **DEFEAT**: coral plate + coral flash. MVP row shows a **CROWN** chip and `*MVP` (or `*YOU` if you are MVP). Your scoreboard row is amber-washed with a **YOU** mark.
3. Structure block lists Blue/Red post and stall tallies. Timeline reads **Posts** then **Stalls** then **Core** (not one flat arrow soup). If Canal Levi was taken this match, a **Levi · Blue/Red take** line appears from the existing buff flags.
4. **Practice again** restarts Practice with the same party/difficulty. **Back to lobby** returns to the Cat Rift stall. **Hub** opens the night-market grid. Auto-return timer still works if you wait.
5. Kitty Caster victory/defeat kill-feed lines still fire. Hub / Yarn Run / Koi / Party / Arcade never show this card.

Smoke (helpers only, not a Studio substitute): `python3 tools/test-end-screen.py /path/to/luau`.

### Studio live-pass (first-Practice tips)

The Luau smoke steps **Next** and **Skip all**, and checks lobby **Show tips** still replays after a dismiss. It does not move a character. Do this in Play.

1. Use a player who has not dismissed tips (a fresh Studio memory store, or a DataStore user who is not done). Hub → **Cat Rift** → **Practice**. After lock-in the cream/coral card sits top-left. Walk, scratch, and cast while it is open. The card does not block the rift.
2. **Next** until the tail: **Purse & Pawmart** (gold, CS, Tab, **7**, Stall Fang, Paper Charm), **Posts, stalls, yarn core**, **Death recap**, **Caster & pings**, **Party queue**, **Closet & voice**. **Got it** on the last card.
3. **Practice again**. The card stays hidden. **Back to lobby** (the Cat Rift stall) and press **Show tips**. The deck starts again at **Move & look**, including those new cards. **Skip all**, then **Show tips** once more. It replays.
4. Open **H / ?** during Cat Rift. The **Tips** row says hub **Live** is the checklist, not a card. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show the tip card.

Smoke (not a Studio substitute): `python3 tools/test-tutorial.py /path/to/luau`.

### Studio live-pass (death recap)

The Luau smoke checks the match-lifetime ring buffer (last 24 hits on each cat), the 12-second window, aggregation by champion / tower / minion / jungle / item, approximate totals, and that the killing blow stays on the short card. It does not move a character. Die in Practice.

1. **Bot.** Easy or Normal. Let Red mid scratch you down. The card sits over the lane, above the ability bar: the bot's name, **Scratch** or the ability (**Paw Slam**, and so on), and an approximate number. The hit that dropped you is marked **killing blow**.
2. **Tower.** Stand in an outer scratching post (an inner lantern stall once that post is down, or the yarn core once it is open). The row names that structure and **Bolt**. A kitten nibble from the last 12 seconds is its own row. A camp swipe names the camp (**Yarn Golem**, **Pigeon Pack**). **Yarn Cleave** is an item slash. **Stall Fang**, when it bites, is its own item row beside the scratch.
3. **✕** dismisses the card, or it hides on its own about **2.5s** before the fountain so the respawn line is readable. A small **Recap** chip above the ability bar opens it again while you are still down. Respawn clears the card and the chip.
4. Kill feed and **Tab** stay. The end screen is unchanged. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade never show the card.

Smoke (not a Studio substitute): `python3 tools/test-death-recap.py /path/to/luau`.

### Studio live-pass (purse chip and Tab)

The Luau smoke checks CS credit: a kitten or camp last hit is +1 CS plus that gold, and kill / assist / tower gold does not add CS. It also checks the Yarn Cleave line (can buy at 280g, short below that, owned once you have it). It does not move a character. Walk a wave in Practice.

1. Lock in. The chip above the ability bar reads **500g**, **0 CS**, **Lv 1**, and **Cleave 280g · can buy** (start gold covers Yarn Cleave). It stays up without holding Tab. The **Recap** button, when you are down, sits underneath it. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show the chip.
2. Last-hit a lane kitten (LMB the one about to die). The chip CS goes up by 1 and gold by **18**. Hold **Tab**: your row's **CS** and **Gold** match the chip, and the team total includes that CS. A kitten that dies to other kittens does not tick your CS.
3. Buy something at the fountain (**B**). Gold on the chip drops by the cost. CS does not. If you are under 280g and do not own Yarn Cleave, the chip says how many gold you are **short**. After you own it, the line reads **Cleave owned**.
4. Let a Red bot farm. Tab's bot row CS and gold move off zero. A kill still pays **180** gold (assist **60**) and does not add CS. A jungle last hit, if you take a camp, adds 1 CS and that camp's gold. Tab and the chip still match when you close Tab.

Smoke (not a Studio substitute): `python3 tools/test-farm-credit.py /path/to/luau`.

### Studio live-pass (meme tape)

The Luau smoke checks bump rules only: a champion kill moves that cat up, a death moves it down by less, an outer post / lantern stall / yarn core moves the taker's cat by a bigger playful step, and lane kittens taking a structure nudge every cat on the attacking team by a smaller step. Lane-kitten and camp last hits are refused. A second bump of the same kind inside the gap is refused so a stuck loop cannot pump one symbol. It does not move a character and it does not talk to a broker. Scratch a bot in Practice.

1. Lock in. A dark tape sits just under the kill feed, one chip per cat in the match (you plus the three Red bots): symbol, price, and a green, red, or flat change. Those prices are play yarn, not gold and not Closet yarn. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show this tape. Meme Arcade keeps its own LOAF / NYAN board.
2. Kill a Red bot. Your chip flashes green and the price steps up. The bot's chip flashes red and steps down a little. The kill-feed scratch line is still there. Kitty Caster, pings, and fog are unchanged.
3. Last-hit a wave of lane kittens. CS and gold move. The tape does not jump on those last hits. A jungle camp is the same.
4. Last-hit an outer scratching post. Your chip flashes and steps up more than a kill. The lantern stall does it again, a bit more. The yarn core is the biggest of the three. If lane kittens snuff a post, the attacking side's chips nudge up together instead of one cat printing the full bump.
5. Die to a bot or a post. Your chip flashes red and dips. There is no yarn button on the tape (`CheerTicker` stays a remote). Prices are fiction. Nothing here spends Robux or touches Meo404.

Smoke (not a Studio substitute): `python3 tools/test-meme-stock.py /path/to/luau`.

### Studio live-pass (kill feed)

UI only. Combat scoring, Kitty Caster line choice, and ping text stay as they were. The Luau smoke checks plate kinds, age fade, announce hold, and your-kill / your-death rings. It does not move a character. Do this in Practice.

1. Lock in. The feed is a short stack of tinted chips under her banner (not bare mono lines). **WE ARE LIVE** reads as a quiet amber announce chip. The meme tape stays just under the stack with a clear gap — no overlap.
2. Scratch a Red bot. A peach **scratch** chip appears. If that was you, the chip gets a light cream ring. Her **FIRST BLOOD** / streak line still hits the banner and a quieter announce chip; the announce fades sooner so it does not fight the banner.
3. Die to a bot or a post. Your death chip picks up a light coral ring. Older chips fade; the stack caps at four.
4. Knock an outer post (lantern stroke) then a lantern stall (wood / lantern). Unplug the yarn core (pink). Hold **G** for a cobalt ping chip. A teammate level-up stays mint on the feed only.
5. Hub / Yarn Run / Koi / Party / Arcade never show the rift feed.

Smoke (not a Studio substitute): `python3 tools/test-kill-feed.py /path/to/luau`.

### Studio live-pass (Tab scoreboard)

UI only. Purse math, MatchSnapshot fields, kill feed, minimap, and resource bars stay as they were. The Luau smoke checks dead dimming, YOU / ★ labels, Blue/Red section titles, and Items truncation. It does not move a character. Do this in Practice.

1. Hub → **Cat Rift → Practice**. Lock in. **Hold Tab** — the board is a centered overlay, not a modal (you can still move / cast). Release Tab and it goes away.
2. Your row reads **YOU ·** with an amber wash. Blue and Red sit under tinted **BLUE · Whiskers** / **RED · Paws** section headers. Bots keep `(Bot)`.
3. Die (or watch a bot die). The dead row greys out until fountain. Gold / CS / KDA still match the purse chip and the bot rows.
4. Buy a few Pawmart items. The Items column uses short labels (`LC`, `Pink`, `Cleave`, …) and truncates with **…** instead of spilling. A soft **★** marks the living kill lead (end-screen MVP uses the same crown when `mvpUserId` is set).
5. Kill feed, minimap, and HP / mana / XP bars stay put while Tab is held. Hub / Yarn Run / Koi / Party / Arcade never show this board.

Smoke (helpers only, not a Studio substitute): `python3 tools/test-scoreboard.py /path/to/luau`.

### Studio live-pass (Kitty Caster callouts)

The Luau smoke checks line choice and the quiet rules: first blood, double through penta inside 10 seconds, an 8-second gap on ordinary kills, lane-kitten and camp executions stay quiet unless that death is first blood or an ace on a side of 2 or more, and the post / stall / open-core / unplug / victory / defeat copy. It does not move a character and it does not call an LLM. Hear it in Practice. No OpenAI key.

1. **Draft.** Start Practice. The banner is Kitty Caster: practice draft is open, Red is 3 bots, lock a cat. That line does not play in Yarn Run, Koi Pond, Yarn Party, or Meme Arcade.
2. **Live.** Lock in. The kill feed shows **WE ARE LIVE** — posts, then stalls, then the yarn core. The meme tape sits just under that feed (symbol, price, green or red). The banner holds her line for a few seconds, then the keybind hint comes back. A short announcer ping plays. Level-ups stay on the kill feed only; she does not narrate every ding.
3. **First blood.** Kill a Red bot, or let one kill you. The scratch line stays, and a second row says **FIRST BLOOD** and names the cat (**Nyan Rocket (Bot)**, or your champion plus your display name). The same cat killing again within about 10 seconds steps **DOUBLE KILL**, **TRIPLE KILL**, **QUADRA**, **PENTA**. A separate cat's isolated kill inside 8 seconds of the last spoken line stays on the scratch feed only.
4. **Kittens.** Last-hitting lane kittens does not call her. Dying to lane kittens (or a camp) stays quiet unless that death is first blood, or it is the last cat on a side that had 2 or more. Red's three bots going down is an **ACE** when the finisher is not already on a double / triple / penta — one cat chaining them hears the streak instead. You alone on Blue is not an ace. A scratching-post execution can still get a short line once the 8-second gap allows it.
5. **Structures.** Knock an outer post. She names that scratching post and that the stall is open. Snuff the lantern stall: she names the stall. When the last post or stall on that side falls, a second line says the yarn core is **OPEN**. Unplug the core: she names who did it, then **VICTORY** (you) or **DEFEAT** (your core). Victory uses the match-found sting; defeat uses the soft announcer ping.
6. **Chat still talks.** Walk to Kitty Caster in the river and **Talk**. Mock replies still come back with no API key. The transcript includes the callouts from this match. Fountain clerks answer shop questions from their own live-pass. Old Tom's coaching is in his own pass. Closet, voice, fog, and kits are unchanged.

Smoke (not a Studio substitute): `python3 tools/test-announcer.py /path/to/luau`.

### Studio live-pass (inner towers)

Not covered by a full Studio substitute. Layout, gates, and HP-bar visibility rules are in `tools/test-structure.py`. Walk the rest in Studio Play:

1. Practice on mid. Red shows a scratching post, then a lantern stall closer to the keep, then a `(gated)` nexus. The stall has a wood awning and paper lanterns, not a second plain post.
2. Auto-attack the post from the river side. The stall does not shoot you there, and its HP does not move while the post stands. Clicking the stall reports that it is still gated. Aiming or scratching the post raises a cream/amber/coral **HP bar** (`current / max`) over it — not the default Roblox humanoid bar. A full-health post you are not aiming at stays quiet.
3. Knock the post over. Kill feed says scratching post. The stall billboard drops `(gated)` and brightens. It now shoots minions and you (lantern-gold bolt, same aggro: recent attacker, else nearest champ, else kitten). Damage the stall: its HP bar appears the same way. Ally posts keep their bars even if the ground fog is dark; an enemy bar does not show through fog.
4. Scratch the stall from the river side of it. The nexus should not be shooting you yet, and it stays `(gated)` until the other lanes' posts and stalls are down. Then the billboard reads `(OPEN)`. When the yarn core is open and you aim or chip it, the bar shows `Yarn core` with current / max.
5. Scratch the nexus. End screen: winner banner, Blue/Red post and stall counts, timeline of what fell.
6. Hub, Closet, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade are unchanged. Fog and recall behave as before.

Practice **never** teleports. `MatchPlaceId` can stay `0`.

### Studio live-pass (kitten / camp HP bars)

Visibility rules are in `tools/test-structure.py` (`showKitten` / `showCamp`). Walk the rest in Studio Play:

1. Practice on mid. Wait for a wave. Healthy kittens stay quiet (plain label only). LMB one: a **small** cream/amber/coral bar with a light Blue / Red wash appears. Scratch it down — the bar tracks HP. Ally damaged kittens keep bars even if the ground fog is dark; enemy kitten bars hide when the body is fogged.
2. Walk to a jungle camp (pigeon, golem, or river crab). Idle full camps stay quiet. Aim or scratch one: a camp HP bar (`name  current / max`) appears while in vision. Step out of vision: the bar hides with the body. Canal Levi still uses the larger epic bar while UP in vision (not this small-camp rule).
3. Scratch a post or stall: structure bars still work. Champion nameplates are unchanged. Pawmart, bots, and kits behave as before.

Smoke (not a Studio substitute): `python3 tools/test-structure.py /path/to/luau`.

### Studio live-pass (Pawmart items)

The Luau smoke names **Yarn Cleave**, **Stall Fang**, and **Paper Charm**, and checks the cleave circle, the 20% bite, and the charm window. It does not move a character. Walk these in Practice. **5** is still Whisker Lens. **6** is still Control Yarn, and it still caps at 2 charges. Champion kits, fog, party, and towers stay as they were. Hard bots buy from this register; the plan and the cleave/lens gates are in the bot Pawmart pass below.

Costs stay in the old 75–300 band because Practice starts at 500 gold. Yarn Cleave is 280 so one Control Yarn (75) still fits in that purse. Stall Fang is 300, the top of the band, so Longclaw (250) plus the fang waits on a wave (minions are 18, a kill is 180) instead of a 400–600 upgrade that would eat the first shop. Paper Charm is 220, next to Mana Treat and Pounce Boots (200) and under Yarnplate (250).

1. **B** at your fountain. Pawmart lists the original six plus Yarn Cleave, Stall Fang, and Paper Charm. Buy a second Control Yarn, then a third: the card stops at 2/2. Buy Whisker Lens, then try again: it stays owned. Key **5** still sweeps wards. Key **6** still plants the magenta ball.
2. Buy **Yarn Cleave** (280g). The HUD reads **7 Cleave ready**. Stand next to a visible bot and a kitten and press **7**. A pink puff, both lose a chunk (about 40 before armor), and the chip counts down. Press **7** again immediately: a toast says it is cooling down. A whiff (nobody in the 12-stud circle) still starts the cooldown. After about 12 seconds it reads ready. Press **7** during a recall: the mint circle drops and the slash still goes off. A bot inside brush you are not in does not take the slash.
3. Buy **Stall Fang** (300g). Auto-attack a full-health bot and remember the chunk. Get that bot to about 20% HP and hit again: the chunk is larger (about 36 more before armor). A full-health kitten does not get that extra bite. Your cat's Q W E R still do what that cat's kit says.
4. **Hard** practice, with **Paper Charm** (220g). Let Red mid leave the fountain and drop the free pink. Walk into that magenta circle. Walk speed stays full and the HUD shows **Charm** for about 2.4 seconds. Step in again before 20 seconds: you slow down, and the HUD counts **Charm**. After that cooldown, the next step into the pink opens the window again. Your own pink slows enemies, not you, so it does not pop the charm.
5. Hub modes, fog, party queue, towers, and jungle bots behave as before.

### Studio live-pass (flagship kits)

The Luau smoke checks the hook table (guard math, pull, takedown reset slots, channel interrupt numbers, mana refund, zone pulses). It does not move a character. Walk these three in Studio Play:

1. **Chairman Meow** (Golden Parachute). Cast **W** (Board Meeting). You heal, the HUD shows **Guard** for about 2.5 seconds, and a squat gold bubble appears. Scratches in that window hurt less than the same hit a moment later. Cast **R** (Executive Order) on a bot: damage, a short stun, and a pull toward the point. The ring is gold with inward ticks, not a plain coral slam.
2. **Nyan Rocket** (Encore). Take a bot down. **Q W E** come off cooldown; **R** does not. Cast **R** (Hyperbeam): you root, a pink channel ring shows, and the bar says the beam can be cancelled. A new move (release WASD and press again if you were already holding it), another cast, or a hit before it finishes — the bolt does not fire, and R returns sooner than the full cooldown. Stand still and the thick pink line fires.
3. **Professor Whiskers** (Office Hours). Land **Q** (Lecture Laser) on a bot. Mana ticks back once for that bolt. A minion-only hit does not. The bolt reads as a thin cyan lecture, not the default coral ball. Cast **E** (Pop Quiz). A blue diagram stays on the ground and ticks instead of one pop. A bot can walk out of it.
4. Lock **Hexkit** afterward. Hexkit and Mindwhisker do not gain a guard, a reset, a breakable beam, Whiskers' quiz zone, a knock, a wick, or a sweater. Their own kits are in the last expansion pass. **Chonk Knight** is in the original-kit pass below. **Bytekit** is in the expansion pass. **Chromeclaw** is in the second expansion pass.
5. Hub modes, fog, party queue, towers, and jungle bots behave as before.

### Studio live-pass (original kits)

The Luau smoke names **Settled Loaf**, **Charge Knock**, **Open Wick**, **Hype Candle**, **Second Helping**, and **Sweater Aura**. It does not move a character. Walk these three in Studio Play. Meow, Nyan, and Whiskers should still match the flagship pass above.

1. **Chonk Knight** (Settled Loaf + Charge Knock). Cast **E** (Belly Flop). The slam still hits, the HUD shows **Guard** for about 2.2 seconds, and a squat gold bubble appears. Scratches in that window hurt less than the same hit a moment later. This cut is a bit shorter and milder than Meow's W. Cast **Q** (Chonk Charge) through a bot: they take the roll's damage, slide further along the charge, and get a short stun (stars). A whiff does not knock. The trail is chonk-orange with a shove tick, not a plain blue dash.
2. **Scammy McMittens** (Open Wick + Hype Candle). Land **Q** (Pump & Dump) on a bot. The HUD shows **Wick 1**, and a thin green candle pops at the point. A minion-only hit does not add a wick. Land two more on cats: **Wick 3**, and it does not climb past 3. The stack lasts about 8 seconds. Cast **E** (Hype Candle) on that bot: the poke is bigger than the same E at Wick 0 (three stacks is a bit more than double on the cat), then **Wick** clears. Minions in the splash do not get that bonus and do not spend the wick if no cat was hit. The splash is a green ring with a gold core.
3. **Grandma Fluff** (Second Helping + Sweater Aura). Cast **Q** (Warm Milk). The heal is a little stronger than the printed 85 (the server multiplies Grandma's heals by 1.22, including Sunday Dinner). Cast **W** (Knitted Sweater). You mend, the HUD shows **Guard** for about 2.4 seconds, and a cream bubble appears. Scratches in that window hurt less. The cut is milder than Meow's guard. In a party practice, a teammate inside the ring gets the same Guard; a stronger guard already on them (Meow's W) is left alone. Solo, you still get the sweater.
4. Lock **Hexkit** afterward. Those buttons do not gain Guard, Wick, a cream aura, or a knock. Hexkit and Mindwhisker are in the last expansion pass. **Bytekit**, **Sir Scratchalot**, and **Shadowpounce** are in the expansion pass below. **Chromeclaw**, **Oracle Paws**, and **Archmeow** are in the second expansion pass.
5. Hub modes, fog, party queue, towers, and jungle bots behave as before.

### Studio live-pass (expansion kits)

The Luau smoke names **Packet Buffer**, **Overclock**, **Honor Bleed**, **Shield Fortify**, **Alley Mark**, and **Smoke Vanish**. It does not move a character. Walk these three in Studio Play. The original six should still match the passes above.

1. **Bytekit** (Packet Buffer + Overclock). Hold **Q** (Laser Pointer Protocol) and release through a bot. The bolt is a cold factory line, not Whiskers' cyan lecture. When it touches the bot, the HUD shows **Data 1**. A minion-only hit does not. Land two more on cats: **Data 3**, and it does not climb past 3. The stack lasts about 6 seconds. Cast **W** (Firmware Patch). You still heal, **Data** clears, and a shield count appears (three stacks is 126 plating). **W** at Data 0 heals and adds no shield. The patch reads as a steel ring.
2. **Sir Scratchalot** (Honor Bleed + Shield Fortify). Cast **Q** (Cleave) on a bot. The HUD shows **Bleed 1**, and red cut ticks pop at the point. A minion-only hit does not. Land two more on cats: **Bleed 3**. Later cleaves, and **R**, hit that cat harder while the cut is up (three stacks is about half again). Minions stay on the printed number. The cut lasts about 7 seconds. Cast **E** (Shield Bash) on that bot: the bash stuns, the hit is about double the same E at Bleed 0, **Bleed** clears, the HUD shows **Guard** for about 2 seconds, and a squat red bubble appears. Scratches in that window hurt less. This cut is milder than Meow's W and a bit milder than Chonk's loaf. A whiff does not fortify. **W** is still the tower shield: it does not bleed or fortify.
3. **Shadowpounce** (Alley Mark + Smoke Vanish). In a lane, cast **Q** (Backstab) on a bot. Damage is ordinary and the HUD does not say **Mark**. Step into a jungle brush pocket. You hide the same way as any other cat — fog and brush are unchanged, and Vanish is not invisibility. From inside that pocket, **Q** a bot in the circle. The HUD shows **Mark**, and a dark ring sits on the point. The mark lasts about 6 seconds. Cast **W** (Smoke Dash). You dash through a smoke streak, and the HUD shows **Vanish** for about 2.5 seconds. Hit that marked bot with **Q**, **E**, or **R** before it ends: the hit is harder than vanish alone (the window is +40%, a mark adds another +55%), then **Vanish** and **Mark** clear. **W** into an unmarked bot, then a champion hit, still gets the smaller vanish bonus and clears **Vanish**. A minion does not spend the window.
4. Lock **Hexkit** afterward. Those buttons do not gain Data, Bleed, Mark, Vanish, or a kit Guard. Mindwhisker matches that. **Chromeclaw**, **Oracle Paws**, and **Archmeow** are in the pass below. Hexkit and Mindwhisker are in the last expansion pass.
5. Hub modes, fog, party queue, towers, and jungle bots behave as before.

### Studio live-pass (expansion kits, second batch)

The Luau smoke names **Chrome Plate**, **Lunge Reload**, **Ward Omen**, **Foresight Veil**, **Spell Charge**, and **Charged Meteor**. It does not move a character. Walk these three in Studio Play. The earlier kits should still match the passes above. Q is learned at level 1, W at 2, E at 3, and R at 6, same as every other cat.

1. **Chromeclaw** (Chrome Plate + Lunge Reload). Cast **Q** (Plasma Claw) on a bot. The HUD shows **Plate 1**, and a teal shard pops at the point. A minion-only hit does not. Land two more on cats: **Plate 3**, and it does not climb past 3. The stack lasts about 7 seconds. Scratches in that window hurt a little less (three plates is about 18% off — milder than Meow's guard, Chonk's loaf, and Scratch's fortify). **W** is still the hard-light shield: it does not store Plate. Hold **E** (Overclock Lunge) and release so the landing sits on that bot. The dash is a chrome streak, the hit is harder than the same E at Plate 0 (three plates is about two-thirds again), **Plate** clears, and E's cooldown shows about 2.8s instead of 7. A whiff keeps Plate and the full cooldown. You take full scratches again once Plate is gone.
2. **Oracle Paws** (Ward Omen + Foresight Veil). Away from any allied ward, cast **W** (Fate Thread) on yourself. The mend is the printed heal. Drop **4** (trinket) and stand within about 24 studs of it. Cast **W** again: the bar jumps further (heals and shields are ×1.28 beside an allied ward, a bit above Grandma's always-on amp, and only while you are next to your own trinket or pink). An enemy ward does not count. Fog and the ward itself are unchanged. Cast **E** (Hex Ward) on yourself beside that trinket: the shield count is thicker than the printed 110 (a bit over 140 once E is learned), the ring is lilac, and the HUD shows **Omen** for about 3.2 seconds. The next scratch in that window is lighter (about 30% off, one hit) before it reaches your shield or HP, then **Omen** clears. A second scratch is full. **E** away from the ward still gives Omen, with the printed shield. **R** beside the ward mends harder and does not grant Omen. **Q** stays an ordinary scratch.
3. **Archmeow** (Spell Charge + Charged Meteor). Cast **Q** (Missile Paw) on a bot (ground: press, then click). The HUD shows **Charge 1**, and an indigo spark pops at the point. A minion-only hit does not. Land two more on cats: **Charge 3**, and it does not climb past 3. The stack lasts about 8 seconds. **W** and **E** do not charge. Cast **R** (Meteor Litter) on that bot: a blue beam falls, the hit is harder than the same R at Charge 0 (three charges is a bit under double on the cat), and **Charge** clears. Minions in the litter stay on the printed number and do not spend the charge if no cat was hit. A whiff keeps Charge.
4. Lock **Hexkit** afterward. Those buttons do not gain Plate, Omen, Charge, or a kit Guard. Mindwhisker matches that. Both are in the pass below.
5. Hub modes, fog, party queue, towers, and jungle bots behave as before.

### Studio live-pass (last expansion kits)

The Luau smoke names **Curse Stacks**, **Hex Zone**, **Psi Mark**, and **Mind Nudge**, and checks that all 14 champions have a non-zero kit plan. It does not move a character. Walk these two in Studio Play. The earlier twelve should still match the passes above. Q is learned at level 1, W at 2, E at 3, and R at 6, same as every other cat.

1. **Hexkit** (Curse Stacks + Hex Zone). Cast **Q** (Chaos Spark) on a bot (ground: press, then click). The HUD shows **Curse 1**, and violet sparks pop at the point. A minion-only hit does not. About a second later the bot's health ticks down on its own (8 per stack before armor). Land two more on cats: **Curse 3**, and it does not climb past 3. Three stacks burn for 24 a second before armor. The curse lasts about 6 seconds, then the burn stops. **W** and **E** do not store Curse. **E** is still the stun bolt. Cast **R** (Unstable Nova) on that bot: the first hit is the printed nova, then a purple hex stays on the ground and ticks about three more times over 2.4 seconds. Each tick is a slice of the nova (about 16%), and a cursed cat takes more (three stacks is about three-quarters again on those ticks only). A cat who walks out of the hex stops taking the ticks. The curse burn continues until it expires, inside or outside the hex. A whiff still leaves the hex. Minions in the hex take the slice and do not gain Curse.
2. **Mindwhisker** (Psi Mark + Mind Nudge). Cast **Q** (Psi Flick) on a bot you can see (ground: press, then click). The HUD shows **Psi**, and a pink ring sits on the point. A minion-only hit does not. The mark lasts about 6 seconds. Cast **Q** again while you can still see that bot: the hit is harder than the first (about a third again). Break sight — a wall, or the bot steps into brush you are not in — and the next champion hit is the printed number. Fog and brush hiding are unchanged; the bonus only reads vision. Cast **E** (Force Shove) on the marked bot: they still take the stun, they step about 8 studs toward you (shorter than Meow's pull, and toward you rather than toward the circle), the hit is harder if you can see them, and **Psi** clears. An unmarked shove stuns and does not pull. **R** (Psychic Storm) does not spend the mark. If **Psi** is still up and you can see the bot, the storm hits harder; if you already nudged, it is the printed stun. **W** is still the bubble: it does not mark or nudge.
3. Hub modes, fog, party queue, towers, and jungle bots behave as before.

### Studio live-pass (Hard jungle bots)

Not covered by the Luau smoke. Camps first spawn about 8 seconds after the match starts. Walk it in Studio Play:

1. **Hard** practice. Red mid is the jungler. Red top and Red bot stay in their lanes and last-hit. They should not cross the river to farm camps.
2. Watch Red mid after the camps pop. They should walk a straight route on their side: **Pigeon Pack (SE)** → **Yarn Golem (SE)** → **south river crab** → **north river crab**. They keep walking that camp between server ticks — they should not shimmy back to mid, and they should not flip between the two crabs while both are up.
3. Stand next to a healthy camp they are clearing (inside about 32 studs). They should turn on you. Let them get a camp under about 40% HP and show yourself again: they should **finish the camp** before chasing. If you only appear far up the lane, in fog, they should keep clearing.
4. After those four camps are down (or you steal them), and **before Canal Levi is up**, Red mid should **rotate** into the lane where your minions are furthest forward, not pace the river. A pink or a recent sighting in another lane can pull that rotate. They should not path to a brush you vanished into and never re-enter. Once Canal Levi is alive (**Levi UP**), Hard mid should leave leftover camps and that rotate for the canal (see the Canal Levi pass). They still finish a camp they already hurt.
5. **Normal** practice, same look: mid only leaves for a camp when their wave is past the river, sticks to that camp until it dies, then goes back to mid. They are not on the Hard route. **Easy** practice: all three Red bots stay in lane. No bot should clear a camp.
6. The Hard jungler still drops one free magenta pink after leaving the fountain. They also leave that fountain already holding Pawmart items (Tab — see the bot Pawmart pass). Fog, last-seen ghosts, inner stalls, recall, hub, Closet, Yarn Run, Koi Pond, and Yarn Party are unchanged.

Smoke for the decision layer (not a Studio substitute): `python3 tools/test-jungle-bot.py /path/to/luau`.

### Studio live-pass (Canal Levi)

The Luau smokes check the 3:00 wake, the one 90-second return, the non-stacking +8% buff, the pit-versus-body minimap rule, the match-clock copy (`Levi 1:24`, `Levi UP`, `Levi 0:47`, `Levi taken`), and Hard mid Levi priority (leftover camps lose, engaged camps finish, peel on a visible enemy at the pit, resume after death). They do not spawn the beast. Fight it in Studio Play and watch the top-left clock. The six small camps are unchanged. Kitty Caster's take line is unchanged.

1. **Practice**, any difficulty. A small clock sits at the **top left**: match time `0:00` climbing as `mm:ss`, and **Levi 3:00** counting down (`Levi 1:24` on the way). The copper **Canal Levi** pad sits in the river between mid and the south crab (`x = 0`, `z = 24`). The beast is not there at 0:00. Camps still pop about 8 seconds in. Levi does not. The hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show this clock.
2. When the clock hits **3:00**, the objective line flips to **Levi UP** and Levi wakes: a large copper ball, about **1100** HP, nameplate **Canal Levi**. A cream/amber/coral **epic HP bar** (`Canal Levi  current / max`) sits over it while it is UP and in vision — the same night-market bar style as posts and stalls, not a Roblox humanoid bar. Fog still hides the living body and that bar with it. It does not sit on the mid lane. It leashes at about **52** studs (a small camp still resets around 38). The line stays **Levi UP** while the body is alive. It does not count down during the fight.
3. With no vision on it, the minimap shows a **bright square pit** at that canal spot, not the body if someone has dragged it. Walk a ward or a cat into vision: the living body appears (a larger round dot), the world model is visible, and the epic HP bar is readable. Step back out: the body and bar hide again; the bright pit returns. Fog rules are the same as any camp. After a take the pit goes **muted** for the return window; after the second death it is a **faint gray** (`Levi taken` on the clock). The clock is not a second pit.
4. Last-hit it (the killing scratch). The objective line starts the return countdown at **Levi 1:30** and counts (`Levi 0:47`). Your purse chip gains **Canal Levi · +8% damage**. If the other side already holds the buff, that same line adds **· Red too** or **· Blue too**. If only they hold it, the chip says **Red holds Levi** or **Blue holds Levi** instead. Kitty Caster says Canal Levi is down and names your side — that spoken line does not become the clock. Autos and abilities hit about 8% harder for the **rest of the match**. Yarn Cleave, towers, and kittens do not get that amp. A second take does not add another 8%. Gold is **140** and CS goes up by 1. The meme tape does not move.
5. When the countdown hits the return, the line is **Levi UP** again. If the other team last-hits that one, they get their own chip and their own caster line. Your buff stays. After that second death the line reads **Levi taken** and stays there. The match clock keeps running. The pit marker leaves. Levi does not come back.
6. **Hard** Practice, wait for **Levi UP**: Red mid should path to the canal and attack it, even if leftover route camps are still up. They finish a camp they already hurt first. Low HP still flees to fountain. If you stand on the pit in their vision, they peel / contest rather than ignore. After Levi dies they resume the jungle route or lane rotate. Red top and bot stay in lane. **Normal** mid only tags along if already mid-river; otherwise ignores. **Easy** never does. Hub, Closet, voice, emotes, aim indicators, and kits are unchanged.

### Studio live-pass (ability aim)

The Luau smoke checks `Targeting.preview` clamp / warn / instant hide. It does not move a character. Feel the indicators in Practice.

1. Draft **Professor Whiskers** (or Bytekit / Nyan). Hold **Q**: a thin cream range ring, and a mint line whose **width matches the kit radius**. Drag the cursor past max range: the line clamps and turns **coral**. Release to fire the traveling bolt. The indicator clears on release.
2. Draft **Chairman Meow**. Press **Q** (Paw Slam) once: the range ring and a ground aim circle stay up. Move the cursor; the circle follows (clamped, coral when past range). **Click** or press **Q** again to confirm. Press **Q** once more, then **Esc** or **right-click**: the ring clears and you see **Cast canceled**. **S** also clears.
3. Press Meow **W** (Board Meeting) or another short-range heal: it fires on press with **no lingering ghost ring**.
4. Hold Meow **E** (Hostile Takeover): a **short streak + tip**, not a full-length line bolt. Coral when past range. Release to dash. Fog still hides Red bots — the local aim parts do not light them up.
5. Kitty Caster, Canal Levi, purse, and ability damage numbers behave as before.

Smoke (not a Studio substitute): `python3 tools/test-combat.py /path/to/luau`.

### Studio live-pass (ability bar CD)

Client-only paint on the Cat Rift ability bar. Cooldown numbers and CombatService timings stay the same. No Luau smoke for the overlays — feel them in Practice.

1. Lock in any kit with mana costs (Whiskers / Bytekit). Cast **Q**. The slot dims with an **ink sweep** that shrinks while the seconds tick. When the timer hits 0, a short **mint flash** pulses on that slot.
2. Dump mana (spam casts / stand without Mana Treat). With a slot off cooldown but mana too low, that slot tints **coral** even though the seconds are gone. Regain mana: coral clears and the slot reads ready again. The **mana bar** under the champion line mirrors that gate with a coral pulse and still shows **current / max**.
3. **4** Ward: same sweep + mint flash language. Buy **Whisker Lens** and **Yarn Cleave**: **5** and **7** match. Buy **Control Yarn**: **6** still shows **×charges** (readable pink), no fake cooldown sweep.
4. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show this bar. Floating damage and world HP bars behave as before.

### Studio live-pass (resource bars)

Client-only Cat Rift AbilityBar paints from existing `combat.health` / `mana` / match `xp`. Regen formulas and max values stay server-owned. Smoke: `python3 tools/test-resource-bars.py /path/to/luau`.

1. Lock in Practice. Above QWER: a **coral** HP fill and **cobalt** mana fill each show **current / max**. The thin **amber** XP bar under them reads **Lv n · into / need** (or **MAX** at 18). The purse chip still sits clear above the bar; the Levi clock stays top-left.
2. Take damage until under **30%** HP — the HP track warn-pulses coral. Dump mana until a ready QWER slot goes coral — the mana track pulses the same gate. Fountain regen clears both pulses without changing the numbers' meaning.
3. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade never show these Cat Rift resource bars. End screen and level-up juice behave as before.

### Studio live-pass (bot Pawmart)

The Luau smoke checks who buys what out of 500 starting gold, and when cleave or lens is allowed. It does not move a character. Hold **Tab** in Practice — the Items column is the bot's bag. Champion kits, fog, party, and the jungle route stay as they were.

1. **Hard** practice. Before Red walks off the fountain, Tab should already list items. A bruiser (Chonk Knight, Sir Scratchalot, Chromeclaw) shows **Yarnplate** and **Paper Charm**. An assassin (Nyan Rocket, Shadowpounce) shows **Longclaw** and **Pounce Boots**. A mage (Bytekit) shows **Mana Treat** and **Longclaw**. Gold is lower than 500. They do not own the whole shop, and nobody lists **Control Yarn**.
2. Let them farm, then meet one back at the fountain. The next purchase is the next item they can afford, in order: assassins pick up **Stall Fang** (300g) only after Longclaw and boots, then **Yarn Cleave** (280g), then **Whisker Lens** (180g). Bruisers and mages pick up Cleave once they have 280g, then the lens. A second visit with gold still short does not buy a later cheaper item ahead of that. When the list is owned, further gold does not add more rows.
3. **Cleave in a 2v1.** Party practice (you and a friend on Blue) or two clients. After Tab shows **Yarn Cleave** on a Hard bot, stand both of you inside about 12 studs of that bot, in the open (not in brush the bot is outside). It slashes: a pink puff, both of you lose a chunk, and it will not slash again for about 12 seconds. One cat alone does not make them press **7**.
4. After Tab shows **Whisker Lens**, drop a trinket (**4**) or a pink (**6**) inside about 32 studs of that bot. They sweep it. Before the lens is on the row, they do not. Red mid still plants one free magenta pink with no Control Yarn charge.
5. **Easy:** the Items column starts as **—**. If one limps home, Tab shows at most **Mana Treat**. **Normal:** they leave naked; a fountain return adds two stat items and never Cleave, Fang, or Charm.
6. Hub modes, fog, party queue, towers, and the jungle route behave as before.

Smoke (not a Studio substitute): `python3 tools/test-bot-shop.py /path/to/luau`.

## 3b. Yarn Run (solo dash)

1. Hub → **Yarn Run**. Pick **Nyan / Shad / Chai** (NyanRocket / Shadowpounce / ChairmanMeow looks) → **Play**.
2. You teleport to a night-market ribbon far from the rift (`MeoYarnRun`). 3/4 chase cam. **A/D** (or arrows) change lanes, **Space** jumps dogs / Roomba gaps, **C** / **Ctrl** slides under laundry signs and the **laundry tunnel**.
3. **Power-ups** (server pickups, big HUD chips): cyan **SPD** bolt = Speed Burst, magenta **MAG** horseshoe = Magnet Yarn (sucks adjacent balls), mint **SHD** dome = one free hit (`SHIELD UP` / `SHIELD POP`), gold **2X** twins = Double Score window. Pickup pops a matching banner + screen flash; the active chip pulses and a soft tint holds while that power is live. Ticker lines match (`SPEED BURST`, `MAGNET ON`, `2X YARN`). All four read as loudly as **SHIELD POP**.
4. **PB / ghost:** a translucent cat replays your personal-best path. Path samples persist in DataStore `MeoYarnGhost_v1` (capped ~240 points so payloads stay small; Studio without API Services is memory-only). A gold **PB {meters}m** gate sits on the ribbon. HUD shows `PB score / meters`. Pass that distance for a **BEAT YOUR GHOST** ticker. Beat the score for **NEW PERSONAL BEST** on the death card. Stop / Play with API Services on: the ghost should still be there.
5. Layout **ramps with distance**: zig-zag dogs, laundry tunnel, Roomba jump gap, yarn fountain, narrow bridge, billboard dodge. Same **daily UTC seed** every run that day (HUD `Daily seed YYYY-MM-DD`) so streamers share a layout. Lane neon + outer rails are a bit brighter; dogs and DODGE walls keep a coral/magenta ground telegraph so hazards stay readable on stream (seed fairness unchanged).
6. Die → fail line or **NEW PERSONAL BEST**, score / yarn / combo, a one-glance **PB compare** strip (`NEW PB … was …` or `PB … · this … (±delta)`), and a **Daily #K · Weekly #K** rank strip (or `Daily — · Weekly —`). Death cam pulls back. Combo ≥ 2 flashes **COMBO BREAK** (banner + coral flash). Near-misses tick **CLOSE!** with a short camera kick. Top 3 **daily** get a podium + ticker (`#1 YARN LORD` / `#2 YARN ACE` / `#3 YARN CREW`). **Retry dash** (same daily seed + ghost) or **Back to hub**. **Leaderboard** opens the board with a **Daily / Weekly** toggle.
7. **Boards:** Hub Yarn Run tile **Board** (and the death-card button) lists top 10. **Daily** is the UTC day (`MeoYarnDaily_v1`). **Weekly** is the UTC week starting Monday (`MeoYarnWeekly_v1`). Roblox **display name**, score, meters, champion tag — or **Anonymous Cat** if **Audio → Hide my name** is on (`MeoSettings_v1`). Studio without API Services is **Save: Memory**. Submit is server-side on death only if the score beats that player's prior for that board (rate-limited). No user ids on the public list. Daily podium titles are unchanged.
8. During a run, a top-right **Daily #K** chip is the stream overlay stub (shows **Daily —** until you are on today's board).
9. Help overlay (**?** / **H**) swaps to runner binds. **T** emotes still work. **G** pings do not.

Score / hits / pickups / board writes are server-authoritative. Personal best + ghost samples persist when DataStore is available (`MeoYarnGhost_v1`); otherwise they last for the Studio session. Daily + weekly ranks persist on their stores. Closet drip and power-ups are unchanged. Cat Rift / Koi / Party / Arcade stall chrome is unchanged (shared ScreenJuice hooks only).

### Studio live-pass (Yarn Run juice)

1. Hub → **Yarn Run → Play**. Grab **SPD**, **MAG**, **SHD**, and **2X** across a few runs (or one long run). Each pickup should flash a matching banner + tint; the HUD chip should pop larger for a beat and stay readable. **SHIELD POP** still coral-flashes when a hit spends the shield.
2. Weave dogs / signs so a near-miss fires **CLOSE!** (visible ticker + short camera kick). Build a combo ≥ 2, then die — **COMBO BREAK** must be obvious before the death card.
3. Confirm lane neon and dog / DODGE ground pads read under chase cam. Daily seed on the HUD matches another client that day.
4. On death, the card shows score/yarn/combo, a clear **PB compare** line, and **Daily / Weekly** ranks (or dashes). Retry keeps the same seed + ghost. **Hide my name** still lists **Anonymous Cat** on the board.
5. Open Cat Rift / Closet / Koi / Party / Arcade — no Yarn Run tint or death card bleed.

## 3c. Koi Pond (solo fishing)

1. Hub → **Koi Pond → Play** (tile **Board** opens today's catch list without playing). You teleport to a lantern canal far from the rift (`MeoKoiPond`, east of the map). Cozy 3/4 dock cam. **Back to hub** returns like Yarn Run; HUD **Daily board** is the same UTC list.
2. **Space** or **Click** **casts** a yarn bobber (bobber reads `…` while waiting). Wait for a nibble (do not mash — an extra press spooked the canal).
3. When the nibble hits, the bobber pops **NIBBLE!** with a soft splash, the HUD lantern rail pulses, and a cream **REEL THE CREAM** banner flashes. **Space / Click** again to **reel**. Hit the bright middle **cream window** (tag flips **REEL → NOW** when the loaf is inside) to land the cat-koi. Miss / timeout: *The loaf swam off* / *Slipped the cream window*.
4. Rarities (Meo canal, not a generic fish UI): cream loaf → peach koi → mint whisker / cobalt braincell → amber lantern → **coral crown**. Tighter window = rarer. Catch pops are rarity-tinted (cream → peach → mint/cobalt → amber → coral) with a score + tag under the name. **LEGENDARY KOI** ticker + coral flash + short camera kick + oversized **CROWN!** fish for the crown.
5. **Stall log** (right) is a session collection with rarity tags (`CREAM` / `UNCM` / `RARE` / `EPIC` / `CROWN`). HUD **Best** line shows name · score · tag · PB · Daily #. **Daily board** (`MeoKoiDaily_v1`, panel title **Canal Daily · Best Catch**) ranks the best **single catch** score of the UTC day (rarity · name · score). Submit is server-side on each catch if it beats that player's prior catch that day (rate-limited). Display names only, or **Anonymous Cat** when hide-my-name is on. Canal day chip is UTC like Yarn Run's daily seed.
6. Help overlay (**?** / **H**) swaps to pond binds (cast / reel). **T** emotes still work. **G** pings do not.

Cast / reel / catch / score / board writes are server-authoritative. Wait / bite / window sizes and rarity weights are unchanged. Yarn Run / Cat Rift / Closet / Party / Arcade stall chrome is unchanged (shared ScreenJuice hooks only). Exclusive with Hub / Moba / Yarn Run (`ModeService`).

### Studio live-pass (Koi Pond juice)

1. Hub → **Koi Pond → Play**. Cast — bobber `…`. On nibble: **NIBBLE!** splash, cream screen flash, **REEL THE CREAM** banner, and a pulsing lantern rail with a bright cream window. Reel inside cream; miss once on purpose and confirm the miss line is obvious.
2. Land cream / peach / mint or cobalt / amber across a few casts. Each pop should tint to that rarity (mint vs cobalt both Rare but different colors) and show `+score · tag` under the name. Stall log rows keep the rarity tag.
3. Land (or force via many casts) a **Coral Crown**. **LEGENDARY KOI** must be unmistakable: coral banner + flash, ticker, camera kick, and **CROWN!** on the fish. Best line and Daily board update if it is the day's best single catch.
4. Open **Daily board** from the HUD (or hub tile). Title reads **Canal Daily · Best Catch**. **Hide my name** still lists **Anonymous Cat**.
5. Open Yarn Run / Cat Rift / Closet / Party / Arcade — no Koi cream tint or rail bleed. Fishing fairness (wait range, bite length, window sizes, weights) unchanged.

## 3d. Yarn Party (lobby join + bots)

1. Hub → **Yarn Party → Play**. You teleport to a night-market courtyard south of the rift (`MeoYarnParty`). High 3/4 cam so all four cats stay on stream. The lobby is **seats 1–4**: you are **[YOU]** in seat 1, and **LoafBot / NibBot / PurrBot** already stand on the other spawns as **[BOT]**. The title counts down (**STARTS IN N**) and pulses each second. The subtitle shows how many cats and bots are seated. The count keeps running when someone joins. If they hop in with under a second left, it stretches to about **1.25s** so they land on a spawn before **GO**. It does not restart from scratch, and it does not freeze.
2. A second (or third) client on the same server hits **Play** during that lobby. They take the first bot seat: that bot model is removed, the human stands on the same spawn, and the board flips **[BOT] → [CAT]**. No second copy of the cat, no extra party. A fourth human fills the last seat. A fifth gets **This party is full — wait for the next one.**
3. **Mid-round** (intro, playing, recap) or while **CROWNED** is up: **Play** does not enter the fight and does not kick the current party. The hub toasts **Wait for the next party**. Scoring stays with the cats already in the round. **Party again** on the podium still starts a fresh lobby.
4. **Back to hub** during the lobby frees that seat. If another human is still waiting, a bot refills it. The last human to leave closes the courtyard. Leaving during a round frees the seat and does **not** drop a bot into the fight.
5. **Three micro-rounds** (not an obstacle-course clone): **YARN DODGE** (hop the coral yarn ball with **Space**; **WASD** to strafe), **STALL FREEZE** (when lanterns blink, stand on a **lit pillow**), then Dodge again. Each intro shows a giant title plus a short rule banner (`Space hop · last loaf standing` / `Lit pillow = safe · lanterns blink`) and a **GO** flash when play starts.
6. Giant round titles, elim pops (`YARN BONK` / `WRONG PILLOW` on a coral event plate + banner + short camera kick), live scoreboard (**[YOU] / [CAT] / [BOT]**). Points: last cat standing 3, timeout survivors 2, then 1 / 0 down the elim order. After round 3: **CROWNED** podium with a highlighted winner strip + **Party again** or **Back to hub**.
7. Help overlay (**?** / **H**) swaps to party binds (lobby, join, late, leave). **T** emotes still work. **G** pings do not.

Seat claims live in `Shared.YarnPartyLobby` and only apply while the phase is Lobby. Scores / elims / bots are server-authoritative. Join polish / scoring math / fog elsewhere are unchanged — this pass is HUD / juice only. Smoke: `python3 tools/test-party.py /path/to/luau`. Yarn Run, Koi Pond, Meme Arcade, and Cat Rift stay exclusive and unchanged.

### Studio live-pass (Yarn Party lobby)

1. **Solo bots.** One client → Yarn Party → Play. Seats 1–4 show YOU + LoafBot + NibBot + PurrBot. Countdown reaches GO without sticking. Three rounds, then **CROWNED** and **Party again**.
2. **Two-client lobby join.** Start the party on client A. Before GO, client B hits Play. B replaces one bot (no duplicate cat). Both boards show YOU / CAT / BOT and the same countdown. The round starts with both humans.
3. **Late join.** While a round is running (or CROWNED is up), client B hits Play. B stays in the hub with **Wait for the next party**. The live score does not gain a new cat.
4. **Leave mid-lobby.** A and B are in the lobby. B hits **Back to hub**. B's seat becomes a bot again if A is still there. When A leaves too, the courtyard closes.

### Studio live-pass (Yarn Party juice)

1. Hub → **Yarn Party → Play**. Lobby **STARTS IN N** should pulse each second; seat rows read as **[YOU]** / **[BOT]** chips (amber for you). Countdown reaches **GO** with a clear flash.
2. On round intro, the giant **YARN DODGE** / **STALL FREEZE** title must be unmistakable and the short rule banner under it must match the round. **GO** flashes before play.
3. Take a yarn hit or wrong pillow (or watch a bot get eliminated). **YARN BONK** / **WRONG PILLOW** must pop on a coral plate + banner with a short camera kick — readable under courtyard cam.
4. After round 3, **CROWNED** shows a highlighted winner strip and obvious **Party again** / **Back to hub**. Scoring and seat takeover still match the lobby live-pass above.
5. Open Yarn Run / Koi / Arcade / Cat Rift / Closet — no Party event plate or crown card bleed. Mini-round rules and points feel the same as before the juice pass.

## 3e. Meme Arcade (solo tape)

1. Hub → **Meme Arcade → Play** (tile **Board** opens today's profit list). You teleport to a neon tape stall west of the rift (`MeoMemeArcade`). 3/4 cam on the ticker wall. **Play yarn only** — the HUD and stall sign say this is not real money / not a broker (disclaimer stays visible during shouts).
2. Start with **100 yarn**. Five cat tickers (LOAF / NYAN / CHNK / BRAIN / RUG) drift on a chaotic micro-market. **Buy** / **Sell** 1 bag at the listed price (cards, or **1–5** buy / **Shift+1–5** sell). A **BOUGHT** / **SOLD** toast pops and the moved ticker card flashes mint/coral. Simple candle bars sit on each card (dark well, clearer bars).
3. Timed round (~28s). Mark-to-market PnL is the big green/red pop. Events shout **TO THE MOON**, **RUG PULL**, **WHALE SNEEZE** on a colored plate + screen flash (and flash the ticker that moved). At the bell, holdings auto-sell with **BOOM** / **BUST**. **Score = profit** vs the starting wallet. Settle card shows one-glance `±yarn · wallet` and **Daily #** / high. Session **daily high** stays in memory; the **daily board** (`MeoArcadeDaily_v1`) ranks that UTC day's best profit (negatives allowed; higher is better). Submit is server-side on settle if it beats that player's prior profit that day (rate-limited). Display names only, or **Anonymous Cat**.
4. **Play again**, recap **Board**, or **Back to hub**. Help overlay (**?** / **H**) swaps to arcade binds. **T** emotes still work. **G** pings do not.

Tape / wallets / events are server-authoritative and **isolated** from in-match `MemeStockService` cheer tickers. Price drift, event magnitudes, and round length are unchanged — this pass is HUD / juice only. Exclusive with Hub / Moba / Yarn Run / Koi Pond / Yarn Party. Yarn Run / Koi / Party / Cat Rift / Closet chrome is unchanged (shared ScreenJuice hooks only).

### Studio live-pass (Meme Arcade juice)

1. Hub → **Meme Arcade → Play**. Buy with **1–5** and the card **Buy** button; sell with **Shift+1–5** and **Sell**. Each fill should show a loud **BOUGHT** / **SOLD** toast and flash that ticker card. Wallet / mark PnL should move.
2. Wait for (or keep playing until) **TO THE MOON**, **RUG PULL**, or **WHALE SNEEZE**. The event plate + screen flash must be unmistakable; the yarn-only disclaimer stays readable under the tape.
3. Let the round settle. **BOOM** / **BUST** card shows score (`±yarn · wallet`) and **Daily #** / high in one glance. **Play again** or open **Board**. **Hide my name** still lists **Anonymous Cat**.
4. Open Yarn Run / Koi / Party / Cat Rift / Closet — no Arcade event plate or settle card bleed. Tape RNG and prices feel the same as before the juice pass.

## 3f. Closet (cross-mode drip)

Hats, collars, shades, and trails/auras. **Parts only** (no meshes). **Play yarn / stall scores only** — there is no Robux cosmetic shop.

1. Hub chrome **Closet** (left of **Mint 404**), or Cat Rift stall **Closet**. Panel: disclaimer, **Save: DataStore | Memory**, closet-yarn wallet, cat silhouette preview, item list with **rarity chips** (`CMN` / `UNC` / `RARE` / `EPIC`) and **source chips** (`STARTER` / `YARN` / `RUN` / `KOI` / `PARTY` / `ARCADE` / `RIFT`). Locked rows dim and show **LOCK**; owned rows show **OWN**; equipped rows show **✓** / **ON** / **Worn ✓**.
2. Starters **Cream Cap** + **Yarn Puff** are owned and equipped on first load. **Equip** / tap **Worn ✓** to unequip. One hat + one trail at a time. Hover a row to **try on** in the silhouette (locked drip ghosts; unlocked drip paints solid). Equip / unlock / buy flashes the preview frame and briefly neon-pulses the avatar's welded drip.
3. **Gold Bell** (collar) costs **25 closet yarn**. New cats start with **40**. Closet yarn is **play points**, not in-match meme-stock yarn and not Robux.
4. Stall unlocks (granted once, then persist even if a daily score resets) — thresholds unchanged:
   - **Coral Beanie** — Yarn Run **200m** (best distance, including non-PB scores; persists with the PB ghost store)
   - **Mint Aura** — Yarn Run **400m**
   - **Canal Crown** + emote flair — catch a **legendary** koi
   - **Party Tiara** + **Moon Dust** (emote flair) — win a Yarn Party (human, not a bot)
   - **Tape Shades** — Meme Arcade daily profit **+15**
   - **Braincell Orbs** + emote flair — Arcade daily **+25**
   - **Lantern Cap** — last-hit an outer scratching post or a lantern stall in Cat Rift (Practice counts; minions and bots do not)
   - **Stall Spark** + emote flair — win a Cat Rift match (Practice counts)
   - **Scratch Tally** — **5** champion kills across Cat Rift matches
5. Equipped drip welds onto the avatar in **hub idle**, **Yarn Run**, **Koi Pond**, **Yarn Party**, **Meme Arcade**, and **Cat Rift** lobby/match (on top of champion silhouettes). Cosmetics marked **emoteFlair** (Canal Crown, Braincell Orbs, Moon Dust, Stall Spark) tint and sparkle the **T** emote bob + billboard for nearby players — the server sends the flair color on `EmotePlayed`. Equip / unlock / buy lines hit a louder ticker + banner + screen flash (`EQUIPPED ·` mint / `UNLOCKED ·` amber / `BOUGHT ·` peach).
6. Loadout persists in DataStore `MeoCloset_v1` when Studio **API Services** are on. Off = **Save: Memory** (same pattern as settings / Meo404). Cat Rift counters (`riftWins`, `riftTowerKills`, `riftKills`) live on that same row, so kills add up across matches. Schema and unlock amounts are unchanged by the wardrobe juice pass. Bots do not wear closet drip and do not earn Rift drip.
7. Match end pays closet yarn: **6** for a win, **2** for a loss. Play points, not Robux, and not in-match gold.

### Studio live-pass (Cat Rift closet)

The cosmetics smoke checks the gates and the yarn tip. It does not walk a lane. Practice is the check.

1. Hub or the Cat Rift stall → **Closet**. Rows show rarity + source chips. **Lantern Cap**, **Stall Spark**, and **Scratch Tally** are **Locked** with a **RIFT** chip. Cream Cap, Yarn Puff, and Gold Bell behave as before.
2. Practice. Last-hit an **outer scratching post** or, after it falls, that lane's **lantern stall**. Minion and bot last hits do not count. Ticker, banner, and flash: `UNLOCKED · Lantern Cap`. Preview frame + avatar drip should pulse.
3. Win the match. Ticker: `UNLOCKED · Stall Spark`. Closet yarn goes up by **6** (a loss pays **2**). Five of your champion kills, including earlier matches this save, ticker `UNLOCKED · Scratch Tally` on the fifth.
4. **Back to lobby**. Equip the new hat or trail. `EQUIPPED ·` must be unmistakable (mint banner + flash + preview pulse). It stays on the hub cat and in Yarn Run, Koi Pond, Yarn Party, and Meme Arcade.

### Studio live-pass (Closet wardrobe juice)

1. Hub → **Closet**. Confirm rarity chips and source chips (`RUN` / `KOI` / `PARTY` / `ARCADE` / `RIFT` / `YARN` / `STARTER`) read in one glance. Locked rows are dimmer with **LOCK**; equipped rows show **✓** / **ON**.
2. Hover a locked item (e.g. Canal Crown or Lantern Cap): silhouette **try-on** ghosts that slot. Hover an owned unequipped item: solid try-on. Leave the row: preview returns to equipped drip.
3. Equip Cream Cap or Yarn Puff (or buy Gold Bell if you have yarn). `EQUIPPED ·` / `BOUGHT ·` ticker + banner + screen flash + silhouette flash + brief avatar neon pulse. Unlock thresholds and closet yarn costs feel unchanged.
4. Hold **T** with Moon Dust / Canal Crown / Braincell Orbs / Stall Spark equipped — emote flair still tints. Open Yarn Run / Koi / Party / Arcade — no Closet panel bleed (shared ScreenJuice hooks only).

Smoke (not a Studio substitute): `python3 tools/test-cosmetics.py /path/to/luau`.

Help overlay lists Closet on the hub sheet. ModeService gates are unchanged.

## 4. Queue and same-server party (2+ clients)

Defaults: `MinPlayersToStart = 2`, `MatchPlaceId = 0` (match starts **in this server**), `PadQueueWithBots = true` (fill to 3 per side). Party queue does not change those defaults and does not require a reserved server.

1. Two Studio clients (Team Test / local server + players) or two published clients.
2. With no party, both hit **Queue**. HUD shows count / ETA. Two solos can land on opposite teams.
3. On **Match found** you should hear the stinger. With `MatchPlaceId = 0` (or Studio), the lobby line reads **MATCH FOUND · in-place** and the blurb says the draft starts in-place. Reserved teleport needs a published PlaceId (hub **Live**, §7). Draft still starts here.
4. **Invite** is same-server only (not Roblox friends, not cross-server):
   - Cat Rift stall → **Invite {name}** (Next cycles when more than one other cat is here).
   - The other cat gets **Accept** / **Decline** for 20 seconds, including a toast if they are still on the hub grid.
   - **Accept** makes one party. The line reads `Party · You (leader) · Sam` or `Party · Alex (leader) · You`. Solo reads `Party · solo`.
   - **Decline**, **Leave party**, or letting the invite expire clears it. A disconnect clears it too. Nobody stays stuck on an old party card.
5. **Queue together:** only the leader's **Queue party** enters every party member who is free in the hub. A member who hits **Leader queues** gets a clear no and does not solo-queue. Leader **Cancel queue** pulls the whole party and tells them. A member can leave the queue alone; the leader is told. If the leader is already queued when someone accepts, that cat joins the queue too.
6. **Practice:** leader **Practice with party** starts one in-place Practice. Party humans share **Blue**. Three red bots are the enemy (`PracticeAllies` stays 0, so a party of two is 2v3). Solo **Practice vs 3 bots** is unchanged while the line says solo. **Practice again** on the end screen brings the same party. `MatchPlaceId` can stay `0`. Practice never reserves a server.
7. Someone in Yarn Run, Koi Pond, Yarn Party, or Meme Arcade is not pulled into the queue or Practice. The leader is told they stayed in that stall.

A party that queues into a real match shares one team. The other side is the other party, solos, or bots. Two unpartied cats still split Blue / Red.

Smoke for the decision layer (not a Studio substitute): `python3 tools/test-rift-party.py /path/to/luau`.

Reserved teleports need a **published** experience and a real `MatchPlaceId` — see §7. Studio `ReserveServer` fails closed and starts in-place.

## 4b. Team voice

Real microphones need a **published** experience. Studio Solo Play stays **Voice · Studio** / **You: not eligible**. This repo's Luau smoke does not open a mic, and a cloud run cannot claim Studio voice was verified.

`Config.Voice.Mode = "Team"` (default) writes an allow-list of **human teammates only**. Bots are not peers. Enemies are never on the list. The list is rewritten when sides form or change (lobby → draft → live → end screen → back to lobby) and again for a couple of seconds after death or respawn, because a new `AudioDeviceInput` would otherwise be heard by every cat.

`Config.Voice.OutsideMatch = "Off"` (default) keeps the hub, the pre-queue lobby, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade quiet (empty allow list). Set it to `"Proximity"` if those stalls should use normal spatial voice instead. `Mode = "Proximity"` never writes a team list.

1. Publish. **Experience Settings → Communication → Enable Voice Chat**. Two age-verified 13+ accounts with voice opted in. Use **two published clients**. Team Test is not this pass. Solo Play is not this pass.
2. Hub: the pill reads **Voice · Off** (or **Proximity** if you changed `OutsideMatch`). **You:** is **live**, **muted**, or **not eligible** — not a blank. **Mute me** / **Unmute** sets the local mic only. **No mic** means there is no device yet. Open **Audio** and confirm SFX and Music still have their own sliders; the hint says the mic lives on the voice pill.
3. Practice vs 3 bots: you are Blue, Red is bots. If voice is actually up, the pill stays Ready and says bots are silent / no voice teammates. It should not look like a broken error. There is nobody on the other side to hear you.
4. With two humans, talk in draft, in the fight, and on the end screen. Same side hears you. The other side does not. Die and respawn: teammates still hear you; enemies still do not. Leave the match: the hub goes quiet again (or proximity, if that is the config).
5. A small pulse on your pill (and a dot on a teammate nameplate) appears only when the client Audio API reports amplitude. If this engine build has no analyzer, the pill says **Mic armed** and nameplates stay quiet. That is not a fake enemy indicator. The server meter is always silent, so speaking is never replicated.

Smoke (lists and copy only): `python3 tools/test-voice.py /path/to/luau`.

## 5. Keybinds (after PRs 1–12)

Same list as the in-game **?** / hold **H** panel.

| Input | Action |
| --- | --- |
| **LMB** | Lock auto-attack on an enemy champ, minion, jungle, ward, or (ungated) structure |
| **X** then click | Attack-move (walk + auto-acquire) |
| **S** | Stop attack / cancel channel orders |
| **Q W E R** | Abilities. **Hold** line/dash, **release** to fire a traveling bolt (or dash). **Ground:** first press arms the ring; **LMB or same key** confirms at cursor; **Esc / RMB** cancels. Instant kits fire on press. Ability bar: ink sweep while cooling, mint flash when ready, coral tint when mana is too low |
| **Meow** | W: guard · R: pull stun |
| **Nyan** | Kill resets QWE · R can break |
| **Whisk** | Q mana back · E zone ticks |
| **Chonk** | E: loaf · Q: knock |
| **Scammy** | Q: wick · E: candle |
| **Grandma** | Heals amp · W: aura |
| **Esc / RMB** | Cancel armed line or ground aim (RMB still works if the camera ate the click) |
| **4** | Trinket ward (free, stealthed, 70s CD, 60s duration, one live) |
| **5** | Whisker Lens (buy at Pawmart first) |
| **6** | Control Yarn / pink ward (buy, 2 charges). Visible magenta ball; slows; reveals enemy trinkets |
| **7** | Yarn Cleave (buy at Pawmart). Circle slash, 12s cooldown. Stall Fang and Paper Charm are passives |
| **B** | Pawmart — **fountain only**. Not recall |
| **F** | Recall 7s → fountain. A new move, ground click, AA, attack-move, or cast cancels immediately. Damage still cancels. Camera, help, emote, ping, and **B** do not |
| **T** (hold) | Emote wheel (Meow, Hiss, Purr, Flex, Dance, Laugh, Cry, GG). Aim a wedge, **release to cast**, or click. **Esc** cancels. Server cooldown (~2.6s); no emote while down. Closet **emoteFlair** (Moon Dust, Canal Crown, …) tints + sparkles the FX |
| **G** (hold) | Smart ping wheel: Caution, On My Way, Assist, Enemy Missing, All Clear, Attack Here. Release or click. Team-only. ~2s cooldown. A visible cat, post, stall, yarn core, ward, or camp is named (`⚠ Caution · Nyan Rocket`). Ground stays generic |
| **Clock** | Top-left during a Cat Rift fight only: match `mm:ss`, then the Canal Levi line (`Levi 1:24`, `Levi UP`, `Levi 0:47`, `Levi taken`). Hidden on the hub and the other stalls |
| **Purse** | Above the ability bar during a Cat Rift match: your gold, CS, level, and whether Yarn Cleave (280g) fits. Same numbers as Tab. Hidden on the hub and the other stalls. After your side takes **Canal Levi**, the chip adds **+8% damage**. If the other side holds it, that same line names them |
| **Canal Levi** | One river epic. Wakes about 3:00 in the canal between mid and the south crab. The clock counts down, shows UP, counts the one ~90s return, then **Levi taken**. Last hit's team keeps +8% auto and ability damage for the match |
| **Tab** (hold) | Scoreboard: Blue/Red sections, YOU highlight, KDA / CS / gold / level / short items. Dead dimmed. Bots tagged. Non-modal |
| **Death** | Recap of recent scratches (cat / post / kitten / camp / item). **✕** dismisses, or it hides ~2.5s before the fountain. **Recap** reopens while you are down |
| **V** | Toggle locked follow camera |
| **Audio** (top-right) | SFX slider + mute, Music slider + mute (independent, quieter default), mute others' emotes, **Hide my name** (boards show **Anonymous Cat**). Mix + hide-name + last Practice difficulty persist (`MeoSettings_v1`). This is not the mic |
| **Voice** (top-right pill) | **Mute me** / **Unmute** sets the local mic. **You: live / muted / not eligible**. Team matches: teammates only, bots silent. Hub and other stalls follow `Config.Voice.OutsideMatch` (default **Off**). Studio Solo Play stays **Voice · Studio** |
| **Closet** | Hub / Cat Rift wardrobe — hats + trails, yarn points (not Robux) |
| **Invite** (Cat Rift) | Same server. They **Accept** within 20s. Leader **Queue party** or **Practice with party**. **Decline**, **Leave party**, or expiry returns the line to solo |
| **?** or hold **H** | This help overlay |
| Minimap click | Generic **Attention** into fog is fine (team-only). History keeps post squares and lantern stalls, not only dots |
| Talk prompt | Fountain / jungle NPC chat. Kitty Caster stays on mock lines (her callouts are separate). Fountain clerks answer shop / actives / wards / builds from authored tips (Blue receipt voice, Red upseller). Old Tom answers camps, wards, fog, and the Hard route from authored lines. Still no API key |
| **A / D** (Yarn Run) | Switch lane (also arrows). In the Rift, **A** is still engine strafe |
| **Space** (Yarn Run) | Jump a dog or the Roomba gap |
| **C / Ctrl** (Yarn Run) | Slide under a laundry sign / tunnel |
| **Space / Click** (Koi Pond) | Cast the yarn bobber; reel when the loaf hits the cream window |
| **WASD** (Yarn Party) | Run the courtyard. Engine jump **Space** hops the yarn |
| **Space** (Yarn Party) | Hop the coral yarn (Dodge) · walk onto lit pillows (Stall Freeze) |
| **Play** (Yarn Party lobby) | Seats 1–4 count down. A friend takes a bot seat. Mid-round Play waits for the next party |
| **1–5** (Meme Arcade) | Buy 1 yarn bag of LOAF / NYAN / CHNK / BRAIN / RUG |
| **Shift+1–5** (Meme Arcade) | Sell 1 bag at the listed yarn price |

Hub: **Cat Rift** / **Yarn Run** / **Koi Pond** / **Yarn Party** / **Meme Arcade** tiles, **Closet**, **Mint 404**, Audio, **T** emotes, **?**. Cat Rift stall: **Queue** / **Queue party**, **Leave queue**, **Practice**, **Invite**, **Accept** / **Decline**, **Leave party**, **Closet**, **← Hub**. Party line shows the leader and members, or **solo**.

### Combat notes (Cat Rift)

- **Purse:** the server stores `gold` and `cs` on each match player (humans and bots). A last hit on a lane kitten is +1 CS and 18 gold. A jungle camp last hit is +1 CS and that camp's gold. Nearby XP, denied minions, kill gold (180), assist gold (60), tower gold (120), and Pawmart spends do not change CS. The chip above the ability bar and Tab read that snapshot. The chip is Cat Rift InProgress only. Smoke: `python3 tools/test-farm-credit.py /path/to/luau`.
- **Death recap:** the server keeps the last 24 damage hits on each cat for this match only (not a DataStore, not a replay). On death the victim gets a short card: champion, tower, minion, jungle, or item, with **Scratch** / the ability / **Bolt** / **Nibble** / **Swipe** / the item when that label is known, approximate damage, and the killing blow marked. It hides about 2.5s before respawn; **Recap** reopens it while you are down. Kill feed, Tab, and the end screen stay. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not show it. Smoke: `python3 tools/test-death-recap.py /path/to/luau`.
- **Kitty Caster:** authored lines in `Shared.AnnouncerLines`, pushed by `AnnouncerService` to Cat Rift players only (`AnnouncerMessage`). She calls first blood, champion kills, double through penta (10s), an ace on a side of 2+, outer posts, lantern stalls, yarn core open, yarn core destroyed, **Canal Levi**, and a victory or defeat sting. Ordinary kills share an 8-second gap. Lane-kitten and camp executions stay quiet unless they are first blood or that ace. Last-hitting kittens does not call her. Canal Levi does. The kill feed keeps the scratch line and adds her row; the banner holds it for 5 seconds. Talking to her still goes through `AiChatService` (mock, no key). Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade do not get the remote. Smoke: `python3 tools/test-announcer.py /path/to/luau`.
- **Traveling skillshots:** Whiskers / Bytekit / Nyan Q (and other `targeting = "line"` kits) spawn a pooled neon bolt at **72 studs/s**. Damage ticks on the server as the bolt sweeps (~0.05s); the client only follows. Not hitscan.
- **Ability aim:** hold-to-aim line/dash and armed ground AoE draw a thin ForceField range ring plus an aim part (`TargetingIndicator`). Line width follows `radius`. Dash is a short streak + tip. Ground keeps the ring until confirm or cancel (**Esc / RMB / S**). Mint = valid, coral = clamped or out of range. Instant heals/shields never leave a ghost. Local juice only — does not reveal fog. Smoke: `python3 tools/test-combat.py /path/to/luau` (`Targeting.preview`).
- **Ability bar CD:** Cat Rift only. Each QWER slot and Ward / Lens / Cleave chip paints a translucent ink sweep from `readyAt`, a mint ready flash when the timer hits 0, and a coral mana-gate tint when mana is below the next cast cost. Control Yarn keeps `×charges`. Seconds text and CombatService timings are unchanged. Overlays do not block clicks. Hub and other stalls have no ability bar.
- **Resource bars:** Cat Rift AbilityBar only. Coral HP and cobalt mana fills show `current / max` from `CombatState`; amber XP shows `Lv n · into / need` from match XP (`Shared.ResourceBars` + `Progression.progress`). HP under 30% warn-pulses; mana-gate on learned QWER costs pulses the mana track. Purse chip and Levi clock stay clear. No regen or max changes. Smoke: `python3 tools/test-resource-bars.py /path/to/luau`.
- **Minimap paint:** client-only `Shared.MinimapPaint`. Cream you-pip + ink ring; ally cream stroke vs enemy coral stroke; posts / open stalls / core match smart-ping shapes; gated stalls dim; Canal Levi UP pit / respawn / taken / body distinct; click Attention flash. Fog mask stays server-owned; explored tint stays lighter. Smoke: `python3 tools/test-minimap.py /path/to/luau` (also covered in vision / ping smokes).
- **Ground confirm:** first Q/W/E/R on a ground AoE shows the ring; **click or press again** casts at the cursor. **Esc / right-click / S** cancels. Lines and dashes stay **hold-to-aim, release-to-fire**.
- **Bots:** Normal/Hard lead with the same projectile speed (0.7s cap) and sidestep for `travel + 0.12s` so they still dodge the bolt instead of the old instant ray. **Shop:** Hard buys a role plan at the opening fountain through the same Pawmart grant humans use (`ShopService.buyAt`: fountain, gold, stack cap). Easy stays naked until one Mana Treat on a later visit. Normal buys two stat sticks on a fountain return. Hard presses Yarn Cleave when two visible enemy cats are in the 12-stud circle, and Whisker Lens only after buying it and an enemy ward is inside the lens radius. They still do not buy Control Yarn. **Jungle:** Easy never clears. Normal mid takes the nearest own-side camp only after the wave is pushed, and finishes a camp it has already hurt. Hard mid follows pigeon → golem → near crab → far crab and holds that goal between thinks (the old walker used to yank them back to lane every tick, and equidistant crabs could swap). After the route is down, Hard rotates to the furthest allied wave, with an 8-second last-known bias from team vision (allies, trinkets, pinks). When **Canal Levi** is up, Hard mid may path to the canal first if they are not already holding a camp; Normal and Easy ignore it. Camp spots and own-side uptime are map knowledge; enemy champions are not. A hidden cat is not a target. The living Levi is still fog. Smokes: `python3 tools/test-jungle-bot.py /path/to/luau`, `python3 tools/test-combat.py /path/to/luau`, `python3 tools/test-bot-shop.py /path/to/luau`.
- **Pink vs trinket:** **4** is a stealthed team-tinted pillar. **6** (after Pawmart **Control Yarn**, 2 charges) is a magenta ball enemies can see. Pinks grant a bit more team vision, slow foes in 22 studs, and keep nearby enemy trinkets revealed. Hard jungle bots still drop one free pink. Both kinds feed the server fog mask.
- **Pawmart night market:** **7** is Yarn Cleave (280g, 12-stud slash, 12s cooldown, visible enemies only). Stall Fang (300g) adds 36 raw damage to champion hits at or below 20% HP. Paper Charm (220g) ignores an enemy pink slow for 2.4s, then waits 20s. None of the three add flat damage, HP, mana, armor, or speed. Lens stays on **5**. Control Yarn still stacks to 2. Hooks live in `Shared.ItemKits`. Smoke: `python3 tools/test-items.py /path/to/luau`.
- **Fog of war:** unseen ground is a dark overlay (10-stud grid). Vision bubbles come from living ally cats, kittens, towers/nexus, trinkets, and pinks. **Keep walls** and the four **market drums** block eye-height LoS (mid gate open; thin props do not). Minimap uses the same mask. Explored-but-unseen stays a lighter tint after you leave (server match memory, restored on reconnect; not DataStore). Jungle brush hides occupants until an ally source enters that pocket. Enemy traveling bolts hide in fog; yours stay visible. Attack-move / AA will not lock an unseen brush target; attack-move walks into last-known brush. When an enemy cat, kitten, or camp leaves vision, a client ghost fades at the last spot (~1.8s) and does not follow the live body. Night-market HP bars on enemy kittens / camps / structures hide with fog the same way (ally structure and kitten bars may stay). Server owns the set; the client only paints it. Smoke: `python3 tools/test-vision.py /path/to/luau` and `python3 tools/test-structure.py /path/to/luau` (HP visibility).
- **Recall:** **F** channels 7s, then the server teleports you to your fountain. A new move order (release and press WASD / stick, or left-click empty ground) cancels immediately and clears the mint circle. Attack, attack-move, a successful cast, **S**, **F** again, and damage still cancel. Camera, help, emotes, pings, and opening Pawmart do not. Being shoved more than 2.5 studs still cancels. Smoke: `python3 tools/test-recall.py /path/to/luau`.
- **Original kits:** Meow, Nyan, and Whiskers stay as shipped. Chonk's **E** is Settled Loaf (short damage cut) and **Q** is Charge Knock (bowl along the roll). Scammy's **Q** is Open Wick (stack on a cat, max 3) and **E** is Hype Candle (spends the stacks on cats only). Grandma's heals are Second Helping (×1.22) and **W** is Sweater Aura (ally damage cut).
- **Expansion kits:** Bytekit's **Q** is Packet Buffer (Data on a cat hit, max 3) and **W** is Overclock (spends Data as a shield). Sir Scratchalot's **Q** is Honor Bleed (a cut on a cat, max 3; later cat hits from him hit harder) and **E** is Shield Fortify (cashes the cut and a short Guard). Shadowpounce's **Q** from brush is Alley Mark, and **W** is Smoke Vanish (a short ambush window, not invisibility; the next cat hit hits harder, and a mark hits harder still). Chromeclaw's **Q** is Chrome Plate (Plate on a cat, max 3; you take less while it is up) and **E** is Lunge Reload (spends Plate, hits harder, and the dash comes back sooner). Oracle Paws' heals and shields are Ward Omen (×1.28 beside an allied ward) and **E** is Foresight Veil (the next hit on a shielded cat is lighter, once). Archmeow's **Q** is Spell Charge (Charge on a cat, max 3) and **R** is Charged Meteor (spends it so the litter hits cats harder). Hexkit's **Q** is Curse Stacks (Curse on a cat, max 3; the curse burns) and **R** is Hex Zone (a hex that keeps ticking, harder on cursed cats). Mindwhisker's **Q** is Psi Mark (a mark; later hits hurt more while that cat is in your vision) and **E** is Mind Nudge (spends the mark and pulls them toward you). Fog, brush hiding, party, towers, and jungle bots are unchanged.
- Smoke: `python3 tools/test-combat.py /path/to/luau` (Targeting + ProjectileLogic + original-six kit hooks). `python3 tools/test-items.py /path/to/luau` (Control Yarn stacks, Yarn Cleave, Stall Fang, Paper Charm). Studio Play is still the real feel check.

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

### Readiness panel

Hub **Live** sits on the hint row on a wide window. On a narrow window it sits left of Closet when that row has room, otherwise on the tagline row. It opens **Publish / Live**. The server builds it at boot from `Shared.PublishChecklist` and `GetPublishReadiness`. A one-line summary with no ids is also on `ReplicatedStorage` attribute `MeoPublishSummary`. The panel does not edit `Config.luau` and does not block Studio Play.

| Row | Ready | Still Studio stub | Blocked |
| --- | --- | --- | --- |
| Match place | `Match.MatchPlaceId` is set | `0` — queue stays **in-place**. Reserved teleport needs a published PlaceId | — |
| Lobby place | `Match.LobbyPlaceId` is set | `0` — Back to lobby remembers the queue origin | — |
| Developer product | `Nft404.DeveloperProductId` is set | `0` — Studio mock grant | — |
| Voice service | `VoiceChatService` is in the place | — | Service missing. The Rojo tree declares it |
| DataStore API | `GetAsync` pcall succeeded (read-only probe `MeoPublishProbe_v1`) | API did not answer. Memory fallback, Play still works | — |
| Economy | `Economy.Enabled` is on | — | Flag is off |

Each row's fix names the Config key and points here. It never shows a numeric PlaceId or product id. Fill those yourself in `Config.luau` locally.

Smoke (helper + hub panel, not a Studio substitute): `python3 tools/test-brand.py /path/to/luau`.

### Studio live-pass (readiness)

1. Leave Config at the defaults (`0` / `""`). Do not paste a PlaceId or product id.
2. Studio → Play (Solo). API Services can stay off.
3. On the hub, click **Live**.
4. Match place, Lobby place, and Developer product say **Still Studio stub**. DataStore says **Still Studio stub** when API Services are off.
5. Voice service says **Ready** when the Rojo `VoiceChatService` is in the place. The voice pill can still say **Studio** / **You: not eligible** — that is the mic check, not this row.
6. Economy says **Ready** while `Config.Economy.Enabled` is true.
7. Close **Live**. Cat Rift → Practice still starts. Queue **Match found** says **in-place**. Nothing in the panel stops Play.

Also for a live place:

1. Publish the experience (reserved servers and voice need this).
2. **Experience Settings → Communication → Enable Voice Chat**. Testers: age-verified 13+, voice opted in. The live voice pass is **two published clients** (§4b). Studio Solo Play stays **Voice · Studio** / **You: not eligible** — that is expected, not a failed publish. Team Test is not a substitute for the two-client pass. `Config.Voice.OutsideMatch` is `Off` (hub and stalls quiet) or `Proximity` (spatial until a side is assigned).
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

**Floating numbers:** damage dealt or taken by the local player also sends `CombatFx` `kind = "float"` with `amount` + `floatKind` (damage / heal / shield / execute). Cream/coral rises and fades at the target; mint for heals and shields; Stall Fang execute pops are larger and coral-bold. The client merges hits inside ~120ms on the same body and soft-caps about 10 on screen so Yarn Cleave / AoE does not carpet. Fogged enemy bodies you cannot see stay quiet. Enabled only while Cat Rift is `InProgress` (hub and other modes stay quiet). HP bars and death recap still use their own paths; they only share the damage events.

Smoke (format / merge / fog / spam helpers): `python3 tools/test-combat.py /path/to/luau`.

### Studio live-pass (floating combat numbers)

1. Hub → Cat Rift → Practice. Scratch a visible kitten or bot: a cream float rises at the target and fades. Take a hit from a bot or post: a float rises on you.
2. Buy Stall Fang, bring a bot under 20% HP, scratch: a larger coral execute float appears in addition to the main hit.
3. Yarn Cleave (**7**) into a clump: floats merge / cap — the screen does not carpet with one number per kitten.
4. Walk a bot into fog and have an ally (or wait for off-screen trades you do not deal/take): no floats on fogged enemy bodies you cannot see. Your own taken damage still shows.
5. Open Yarn Run / Koi / Party / Arcade or stay on the hub: no Cat Rift combat floats. HP bars and death recap behave as before.

### Studio live-pass (level-up juice)

Client juice only. XP tables and auto-ranks stay in `Progression`. Farm a wave in Practice.

1. Hub → Cat Rift → Practice. Last-hit lane kittens until you level (purse chip **Lv** ticks). A cream/amber **LEVEL UP** banner pops with a soft amber screen flash and the LevelUp ping. A brief amber ring + silhouette flash sits on your cat, and a floating **LEVEL n** rises off the body.
2. Watch the ability bar: the QWER slot that just gained a rank (auto-assign, no + buttons) pulses amber once. Cooldown sweeps and mana tint still behave as before.
3. A Red bot leveling only adds a kill-feed line (`grew another life`). No local banner, no silhouette ring on them for you. Kitty Caster still does not narrate every ding.
4. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade stay quiet. Floating damage numbers and HP bars are unchanged.

Smoke (helpers only, not a Studio substitute): `python3 tools/test-combat.py /path/to/luau`.

## 8d. Map art pass

`MapBuilder` dresses the same 420×280 bounds (lane Z −80 / 0 / 80). Each lane has an outer scratching post at `x = ±90` and an inner lantern stall at `x = ±132` (ears, yarn, wood awning, paper lanterns) before the yarn core at `x = ±168`. Stalls sit outside the keep gate and before minions cut inward (`|x| ≥ 145`). A stall is damage-gated on its own lane's post; the nexus opens only after all six structures on that side fall. Extra decor Parts are `CanCollide = false` and `CanQuery = false` so bots, tower ranges, and click-AA stay the same. The four market drums in `VisionCover` are the exception: `CanQuery = true` and `MeoBlocksVision` so fog can raycast them, still `CanCollide = false` (walk-through, same as keep walls). Client click rays exclude that folder. Lighting is a cozy night-market (`Atmosphere` + mild bloom), not a rave.

## 8e. Cat emotes

Hold **T** in the hub, Cat Rift lobby/match, Yarn Run, Koi Pond, Yarn Party, or Meme Arcade for the 8-slice wheel (Meow / Hiss / Purr / Flex / Dance / Laugh / Cry / GG). Aim a wedge (it scales + glows), **release to cast**, or click. **Esc** cancels without playing. Nearby clients (broadcast ~96 studs — teammates, hub neighbors, and Cat Rift foes) see an emoji billboard + neon Part bob and hear a Sound-kit cue. Server cooldown (~2.6s); no emote while down. **SFX → Mute others' emotes** skips their cues (billboard still shows). Closet **emoteFlair** drip (Canal Crown, Braincell Orbs, Moon Dust, Stall Spark) tints the bob, thickens the billboard stroke, and adds sparkle particles — wired from Closet loadout on the server (`EmotePlayed.flairTint`). **G** pings stay Cat Rift only. No animation binaries. No Robux emote shop.

Smoke (catalog + flair helpers): `python3 tools/test-emote.py /path/to/luau` and `python3 tools/test-cosmetics.py /path/to/luau`.

### Studio live-pass (T wheel + Closet flair)

These are not covered by the Luau smoke:

1. Hub pad: hold **T**, aim **Meow**, release. Billboard + bob appear above you. Hold **T** again and press **Esc** — wheel closes, nothing plays. Aim **Dance**, click the wedge — same juice.
2. Closet → equip **Moon Dust** (or **Canal Crown**). Hold **T**, release **Purr**. The bob and billboard stroke read that flair color and sparkle. Unequip the flair piece; the next emote is plain emote color again.
3. Cat Rift Practice: both sides within ~96 studs see each other's emotes. Spam **T** — second cast inside ~2.6s toasts cooldown. Die — wheel refuses while down.
4. Yarn Run / Koi / Party / Arcade: **T** still opens the wheel. **G** does not ping. Combat aim / Levi / purse are unchanged.

## 8f. Smart pings

Hold **G** in a match (Practice counts) for the 6-slice ping wheel. Aim is captured when **G** goes down. Minimap click stays generic **Attention** (legal in fog). Markers + a kill-feed line go to **teammates only**.

The line names what the ray hit when you can see it: a cat (`Alex: ⚠ Caution · Nyan Rocket`), a scratching post, a lantern stall (`⚔ Attack · Red Mid lantern stall`), the yarn core, a ward (`ward` or `pink`), or a camp (`Yarn Golem`). Empty ground keeps the generic line (`⚔ Attack here`). Kittens are not named.

**Fog:** Attention on a fogged enemy body refuses with **No vision.** (same idea as an auto-attack). It does not drop a marker on that cat. Ground clicks and minimap clicks into fog still send Attention, and Enemy Missing on a hidden body or on fogged ground still sends — unnamed, so the line does not reveal who is there. Other wheel kinds on a hidden body stay unnamed too.

Server cooldown is **2 seconds** per player (`PingLogic.CooldownSeconds`). A second ping inside that window is ignored, so PingSoft / PingWarn do not machine-gun over Kitty Caster. Her banner still holds for 5 seconds; the ping line waits in the kill feed instead of erasing her. Soft cues are unchanged (Caution / Missing / Attack use PingWarn, the rest PingSoft).

Minimap: outer-post pings are **squares** in team color with a lantern-amber stroke. Lantern stalls are **amber circles** with a wood stroke. The yarn core is a pink circle with a yarn stroke. Ground and champ pings stay round dots in the ping color. A short history of those shapes lingers. Hub, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade still do not ping.

Smoke (rules only, not a Studio substitute): `python3 tools/test-ping.py /path/to/luau`.

### Studio live-pass (pings)

1. Practice, lock a cat, and walk up to a visible bot. Hold **G** on the bot and release **Caution**. The kill feed and the world tag read `⚠ Caution ·` plus that cat's name (Nyan Rocket, not the `(Bot)` suffix). Teammates would see it; the enemy team does not.
2. Hold **G** on an inner lantern stall and release **Attack**. The line names that stall (`Red Mid lantern stall` or whichever lane). The minimap mark is a lantern-amber circle with a wood ring, not a bare dot. An outer scratching post is a square. The yarn core is the larger pink mark.
3. Let a bot walk into fog. Attention on the hidden body toasts **No vision.** and does not mark them. Click empty fogged ground, or click the minimap in the fog: Attention still lands, unnamed. Enemy Missing on that fog still lands, unnamed.
4. Ping twice quickly. The second press inside about 2 seconds does nothing. If Kitty Caster just spoke, her banner stays up and the ping line appears in the feed under it. One soft cue plays per accepted ping.
5. Open Yarn Run, Koi Pond, Yarn Party, Arcade, or the hub. **G** does not ping. Closet, voice, and kits are unchanged.

## 8g. Fog of war (Cat Rift)

Practice (or a live match) is the check. Hub / Yarn Run / Koi Pond / Yarn Party / Meme Arcade / Closet must **not** show the rift fog overlay.

- At spawn, fountain + nearby living towers are lit. Walk toward river: ground ahead stays dark until you (or a wave / ward) get there. **Base walls** block sight — you should not see through the keep into (or out of) fountain except via the **mid-lane gate**. The four clay **market drums** (between mid and the side lanes, off the river) hide whatever is directly behind them. Stepping sideways around a drum reveals that pocket. Fountain pillars, drum-top lamps, lane dots, and brush glass do **not** add dark pockets. Clicking a drum still aims at the ground behind it.
- Minimap: dark cells = no vision. Explored-but-unseen is a lighter dark and **stays that way after you leave** — it does not black out again. Rejoin / script reload mid-match should restore the same explored tint (server match memory, not DataStore). A new Practice starts unexplored. Champ pips: **you** are cream with an ink ring; allies keep team fill + cream stroke; enemies keep team fill + coral stroke. Scratching posts are **squares** (lantern stroke); open lantern stalls are **amber circles** (wood ring); gated stalls are dim wood lanterns; the yarn core is the larger pink mark. **Canal Levi**: bright square pit while UP in fog, muted square while returning, faint gray after taken, larger round body only in vision. Click the map for Attention — a short local amber flash lands before the team ping.
- **4** in jungle lights a team bubble. Red should not see your stealthed trinket unless they walk on it, lens it, or a pink reveals it.
- **6** magenta pink is visible to Red even in fog, and still grants your team a vision bubble + slow + trinket reveal. Pink vision still respects walls and thick cover (a drum between the pink and a cell stays dark).
- Stand in a labeled brush pocket: you should drop off the enemy minimap until they enter. You can still see the lane from inside. **LMB / attack-move (X)** must **not** lock an unseen brush target. Attack-move toward a last-seen brush pocket walks **into** that last-known tile (never the hidden live body).
- When a Red cat, kitten, or jungle camp **leaves** your vision, a translucent ghost of that unit stays at the last spot and facing you saw, then fades (about 1.8s). It does not slide toward where they actually went. Seeing that unit again removes the ghost immediately. Ghosts are local juice in `Workspace.MeoLastSeen`: not wards, not minimap dots, and not attack targets. **LMB** still refuses a hidden target. **Attack-move (X)** on the hidden body still walks to last-known brush, not the live tile. Damaged / aimed enemy kitten HP bars and camp bars hide with the body; ally kitten bars can stay.
- Enemy traveling **Q bolts** hide while the projectile is in unseen/unexplored fog, including ground hidden behind a drum. **Your own** bolt stays visible. Server still simulates hits. Pink wards, brush, fog memory, last-seen ghosts, and hub / Closet / Yarn Run / Koi / Party modes are unchanged.
- After **Back to lobby**, the overlay and any ghosts are gone and hub hosts / Closet look normal.

Server authority: `VisionService` builds `fogBits` + match-lifetime `exploredBits` + visible unit ids (radius + brush + eye-height mesh LoS). Memory resets on match start/stop only. Keep walls and upright cover are occlusion volumes; parts tagged `MeoBlocksVision` that are meshes, wedges, or tilted are `Workspace:Raycast` at eye height (a hit blocks, a miss does not open a wall). AA / attack-move refuse fogged champs. Attention pings refuse a fogged enemy body the same way; ground and minimap Attention / Missing into fog still land unnamed. Attack-move can path to last-known brush. The client fades a last-seen ghost from visibility transitions (`LastSeenGhostLogic`); that ghost is not replicated and does not update `fogBits`. Minimap dot paint lives in `Shared.MinimapPaint` (client presentation only). `python3 tools/test-vision.py` covers grid pack, brush, wall LoS, drum cover, thin/short reject, mesh-corner probe, mask OR, ghost freeze/fade, and minimap fog tint, not Studio rendering. `python3 tools/test-ping.py` covers the ping fog rule plus structure marker shapes. `python3 tools/test-minimap.py` covers pip / structure / Levi / click-flash paint.

### Studio live-pass (minimap clarity)

These are not covered by the Luau smoke:

1. Practice, lock a cat. Confirm **you** are the cream pip with an ink ring on the bottom-right map; Blue allies read cream-stroked blue; Red enemies (once visible) read coral-stroked red.
2. Outer posts are **squares**. Walk mid: gated Red lantern stalls are dim wood circles; after you take a Blue post, that lane's stall brightens to lantern amber with a wood ring. The yarn core is the larger pink mark.
3. Wait for **Levi UP** (or skip clock): with no vision, the canal shows a **bright square pit**. Ward or walk into vision — larger round **body** replaces the pit. After a take, the pit goes **muted** for the return, then a **faint gray** after the second death (`Levi taken` on the clock).
4. Click the minimap in fog: a short amber **click flash** pulses at the point, then the team Attention ping lands (unnamed). Fog explored cells stay lighter than unexplored. AbilityBar / end screen / hub look unchanged.

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
- Queue never teleports in Studio: expected. Publish + `MatchPlaceId`. Hub **Live** says that row is still a Studio stub.
- No **Live** panel, or it stays on "Reading the server checklist…": Rojo-sync `Shared.PublishChecklist`, `Server.Publish.PublishReport`, and `Client.UI.PublishPanel`, then Play again. The checklist is not a gate.
- Voice pill says **Studio** / **You: not eligible**: unpublished Solo Play cannot enable experience voice. Publish, enable Voice Chat, then use two eligible clients (§4b). **No mic** means the device is not parented yet. **Mute me** does not change SFX or Music.
- Voice pill says **Off** in the hub: default `OutsideMatch`. Team voice starts when a match assigns your side. Practice against only bots should say they are silent, not that voice crashed.
- Bots idle: you are still in **Champion select** — lock a cat and wait for the timer.
- Bots look like the same box: Rojo-sync `Shared.ChampionLooks` + `Server.World.ChampionAppearance`, then start a new Practice.
- No cast/hit VFX: Rojo-sync so `MeoRemotes.CombatFx` exists, then start a new Practice (FX are server-confirmed, not the hold-to-aim indicator).
- Map still looks like a green slab: Rojo-sync `Server.World.MapBuilder` and replay Practice (lighting is applied on `MapBuilder.build`).
- Whole rift stays fully bright in Practice: Rojo-sync `Shared.VisionLogic` + `Client.Juice.FogOfWar`. Overlay is client-only Parts named `MeoFog`.
- No fading ghost when a bot walks into fog: Rojo-sync `Shared.LastSeenGhostLogic` + `Client.Juice.LastSeenGhosts`. Ghosts are client-only parts in `Workspace.MeoLastSeen` (not server entities). They only appear after you have seen that unit once this match.
- Fog stays on after the match / in Yarn Run: leave Practice via **Back to lobby** first; hub modes call `FogOfWar.setEnabled(false)`.
- No tip card on first Practice: Rojo-sync `TutorialTips` + `GetTutorialStatus`. Replay from lobby **Show tips**. Attribute `MeoTutorialDone` skips auto-start. A player who already finished will not see new cards until **Show tips**. That is intentional (`MeoTutorial_v1` stays a boolean).
- No emote wheel: Rojo-sync so `MeoRemotes.PlayEmote` / `EmotePlayed` exist, then hold **T** in lobby or Practice (not while down). Closet flair: equip Moon Dust or Canal Crown and confirm the bob sparkles.
- No ping wheel, or a ping never names the cat: Rojo-sync `PingCatalog`, `PingLogic`, and `MinimapPing`. Hold **G** in Practice (not lobby) on a visible bot. Minimap click is still generic Attention, including into fog. Attention on a hidden enemy says **No vision.**
- Tape under the kill feed never moves, or the rift tape shows on the hub: Rojo-sync `Shared.MemeStockLogic`, `Server.Economy.MemeStockService`, and `Client.UI.MemeTape`. Champion kills and posts move it. Lane kitten last hits do not. Yarn Run, Koi Pond, Yarn Party, Meme Arcade, and the hub grid do not show it.
- No death recap after a Practice death: Rojo-sync so `MeoRemotes.DeathRecap` exists, then die again in a new Practice. Hub, Yarn Run, Koi, Party, and Arcade do not show it.

## 10. Still stubbed (do not expect)

Live reserved-teleport playtest in this cloud agent, uploaded cat meshes (silhouettes are primitive Parts today), original SFX / music beds (placeholders loop today), compliance-cleared Robux 404 product, production SIWE domain binding + persisted nonces, **Studio or published voice** (the voice smoke checks allow-lists and pill copy only; it does not open a microphone). Fog is a 10-stud cell mask + eye-height mesh LoS (walls, thick cover, raycast for non-box parts) + unit hide + client last-seen ghosts — not per-pixel shaders.

## Hub cast integration (2026-09-15)

The sixth grid slot is **Meet the cats**, beside the five playable modes. Click MEO, ME and MO and verify each opens the matching greeting. Switch cats while a reply is pending and confirm the old reply stays out of the new conversation. Start each game mode from an open chat and confirm the chat closes. Check the portraits and text on desktop and phone; visual Studio validation is still pending.

Verified locally: all 113 Luau sources compile; combat projectile, **recall cancel-on-order**, Control Yarn stacks, **structure layout/gates (outer posts, inner lantern stalls, yarn-core gate)**, **vision/fog + brush + mesh LoS (walls, drums, thin-prop reject, mesh ray probe) + match-lifetime exploredBits + last-seen ghost freeze/fade**, brand/hub, Yarn Run (incl. stall-board ranking + Anonymous Cat), Koi Pond, Yarn Party and Meme Arcade smoke suites pass; Rojo 7.4.4 builds `MeoMeoMeo.rbxlx`. These checks do not replace a Studio playtest.

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
