# Playtest Meo Meo Meo

Step-by-step for running the cat MOBA in **Roblox Studio** or a **published experience**. Source of truth is this Rojo tree. In Play, press **?** or hold **H** for the same keybinds.

Do not commit API keys, `ClaimApiSecret`, or any chain private key.

## 0. What you have

Playable scaffold: **hub grid** (Cat Rift / Yarn Run / Koi Pond / Yarn Party / Meme Arcade) → Cat Rift practice or queue → 14-cat draft → 3-lane fight → end screen → hub. **Yarn Run** dash + daily/weekly board + persisted PB ghost. **Koi Pond** fishing + UTC daily catch board. **Yarn Party** 4-cat micro-rounds (lobby seats, bots hold empties, friends take a seat before GO). **Meme Arcade** timed yarn-tape stall + UTC daily profit board (play yarn only). **Audio → Hide my name** lists you as **Anonymous Cat** on those boards.

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

Build verification on 2026-09-22: Luau compiled 118 sources; combat projectile + kit hooks (Meow guard/pull, Nyan reset/channel, Whiskers refund/zone, Chonk Settled Loaf/Charge Knock, Scammy Open Wick/Hype Candle, Grandma Second Helping/Sweater Aura, Bytekit Packet Buffer/Overclock, Sir Scratchalot Honor Bleed/Shield Fortify, Shadowpounce Alley Mark/Smoke Vanish, Chromeclaw Chrome Plate/Lunge Reload, Oracle Paws Ward Omen/Foresight Veil, Archmeow Spell Charge/Charged Meteor, Hexkit Curse Stacks/Hex Zone, Mindwhisker Psi Mark/Mind Nudge) + recall cancel-on-order + Control Yarn stacks + Pawmart Yarn Cleave / Stall Fang / Paper Charm + structure layout/gates (outer posts, inner lantern stalls, yarn-core gate) + vision/fog (mesh LoS: eye-height walls + thick cover, mesh raycast, 10-stud grid, match-lifetime explored OR, last-seen ghost freeze/fade) + jungle-bot route/commit/rotate + brand/lobby + cosmetics/arcade/koi/yarn/party (lobby seat takeover) smokes passed; Rojo 7.4.4 builds the place. This is build verification, not a Studio playtest.

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
   - **Easy** — slow, panicky, sloppy CS, two items, 0.88× damage. No dodge; will not dive towers. Does not take jungle camps.
   - **Normal** — last-hits, leads traveling skillshots (72 studs/s), sidesteps incoming bolts/AoEs (hang uses travel time), dives only with a crashing wave or a short low-HP chase. Mid, once the allied wave is past the river, clears the nearest own-side camp and finishes it. A champion in their face can pull a healthy camp; a hurt camp is finished anyway.
   - **Hard** — faster, 1.22× damage, tighter CS, full build, one early **magenta control (pink)** ward once they have left the fountain, kill-dives, uses Whisker Lens on revealed enemy wards. Mid runs pigeon pack → yarn golem → near river crab → far river crab, then rotates to the pushed lane. Top and bot stay in lane.
2. You are Blue Whiskers vs **3 Red (Bot)** cats. Draft a cat (Professor Whiskers / Bytekit / Nyan Rocket are easy to read). Cards show a color swatch + ears. After lock-in, you and the Red bots should have **distinct silhouettes** (ears/tail/archetype flair) and nameplates (`Champion · role`, bots keep `(Bot)`). The rift should read as a night-market: gold lane dots, indigo river, fountain lanterns, tower ears / yarn, **lantern stalls** (awning + paper lanterns) between the posts and each keep, jungle camp pedestals. **Fog of war** darkens ground outside ally vision. Your fountain, nearby living towers, and ally minions light bubbles. Red bots in river/jungle stay hidden until they walk into a bubble. When one walks back out, a faint ghost lingers at the last spot, then fades.
3. Walk a lane. Unseen ground stays dark; the minimap matches (no enemy dots in fog). Walk back: cells you already lit stay a lighter **explored-but-unseen** tint (not full black). **LMB** a bot or minion — claw flash + hit spark. You cannot AA a target you cannot see. Hold **Q** if the kit is a line skillshot (aim indicator), **release** to fire a **traveling bolt** (hits on contact, server-authoritative; client VFX follows — bolts are not clipped by the ground fog overlay). Ground AoEs (Paw Slam etc.): **first press** shows the ring, **click or press again** to confirm at the cursor; **Esc / right-click** cancels. Instant heals still fire on press. Dashes stay hold-to-aim + streak. The first-Practice cards include **Three flagship kits** (Meow guard + pull, Nyan reset + breakable beam, Whiskers mana refund + ticking zone), **Three more original kits** (Chonk Settled Loaf + Charge Knock, Scammy Open Wick + Hype Candle, Grandma Second Helping + Sweater Aura), **Three expansion kits** (Bytekit Packet Buffer + Overclock, Sir Scratchalot Honor Bleed + Shield Fortify, Shadowpounce Alley Mark + Smoke Vanish), **Three more expansion kits** (Chromeclaw Chrome Plate + Lunge Reload, Oracle Paws Ward Omen + Foresight Veil, Archmeow Spell Charge + Charged Meteor), and **Last two expansion kits** (Hexkit Curse Stacks + Hex Zone, Mindwhisker Psi Mark + Mind Nudge). Draft blurbs and **H / ?** repeat the short versions.
4. **4** drop a stealthed team-tinted trinket — the pocket it covers should **light up** for your team (and stay dark for Red). Walk a jungle **brush** pocket (NW/NE/SE/SW or river-crab): you vanish from enemies until they enter. **B** at fountain → buy **Control Yarn** (up to 2) → **6** plants a magenta pink ball (visible to everyone, slows, reveals nearby enemy trinkets, grants team vision). Buy **Whisker Lens** → **5** if you see an enemy ward. The same register sells **Yarn Cleave** (7), **Stall Fang**, and **Paper Charm**. On **Hard**, the Red mid jungler may also plant a free pink. See the Pawmart live-pass below.
5. **F** recall (7s) — mint circle under your feet. Stand still and it finishes. A **new** WASD press, a **ground click**, attack, attack-move, a cast, or **7** (Yarn Cleave) cancels immediately and the circle and channel bar disappear. A direction you were already holding does not cancel until you release and press again. Damage still cancels. **B**, **T**, **G**, **H**, and **V** do not. **Tab** scoreboard (bots tagged).
6. Push one lane **outer scratching post → inner lantern stall → yarn core**. The stall billboard stays `(gated)` and takes no damage until that lane's post falls (death puff + kill feed). Stall shots are warm lantern gold and use the same aggro as posts. The nexus stays `(gated)` until all **3 posts and 3 stalls** are down, then `(OPEN)`. Scratch the nexus.
7. End screen shows **VICTORY** or **DEFEAT**, who unplugged the yarn core, post/stall/core counts, and a structure timeline. **Back to lobby** or **Practice again**. Fog overlay and any last-seen ghosts should vanish. Open **Yarn Run / Koi / Party / Arcade / Closet** and confirm hub stalls never paint rift fog.

### Studio live-pass (inner towers)

Not covered by the Luau smoke. Walk it in Studio Play:

1. Practice on mid. Red shows a scratching post, then a lantern stall closer to the keep, then a `(gated)` nexus. The stall has a wood awning and paper lanterns, not a second plain post.
2. Auto-attack the post from the river side. The stall does not shoot you there, and its HP does not move while the post stands. Clicking the stall reports that it is still gated.
3. Knock the post over. Kill feed says scratching post. The stall billboard drops `(gated)` and brightens. It now shoots minions and you (lantern-gold bolt, same aggro: recent attacker, else nearest champ, else kitten).
4. Scratch the stall from the river side of it. The nexus should not be shooting you yet, and it stays `(gated)` until the other lanes' posts and stalls are down. Then the billboard reads `(OPEN)`.
5. Scratch the nexus. End screen: winner banner, Blue/Red post and stall counts, timeline of what fell.
6. Hub, Closet, Yarn Run, Koi Pond, Yarn Party, and Meme Arcade are unchanged. Fog and recall behave as before.

Practice **never** teleports. `MatchPlaceId` can stay `0`.

### Studio live-pass (Pawmart items)

The Luau smoke names **Yarn Cleave**, **Stall Fang**, and **Paper Charm**, and checks the cleave circle, the 20% bite, and the charm window. It does not move a character. Walk these in Practice. **5** is still Whisker Lens. **6** is still Control Yarn, and it still caps at 2 charges. Champion kits, fog, party, towers, and jungle bots stay as they were. Bots do not buy the new three.

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
4. After those four camps are down (or you steal them), Red mid should **rotate** into the lane where your minions are furthest forward, not pace the river. A pink or a recent sighting in another lane can pull that rotate. They should not path to a brush you vanished into and never re-enter.
5. **Normal** practice, same look: mid only leaves for a camp when their wave is past the river, sticks to that camp until it dies, then goes back to mid. They are not on the Hard route. **Easy** practice: all three Red bots stay in lane. No bot should clear a camp.
6. The Hard jungler still drops one free magenta pink after leaving the fountain. Fog, last-seen ghosts, inner stalls, recall, hub, Closet, Yarn Run, Koi Pond, and Yarn Party are unchanged.

Smoke for the decision layer (not a Studio substitute): `python3 tools/test-jungle-bot.py /path/to/luau`.

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

## 3d. Yarn Party (lobby join + bots)

1. Hub → **Yarn Party → Play**. You teleport to a night-market courtyard south of the rift (`MeoYarnParty`). High 3/4 cam so all four cats stay on stream. The lobby is **seats 1–4**: you are **YOU** in seat 1, and **LoafBot / NibBot / PurrBot** already stand on the other spawns as **BOT**. The title counts down (**STARTS IN N**). The subtitle shows how many cats and bots are seated. The count keeps running when someone joins. If they hop in with under a second left, it stretches to about **1.25s** so they land on a spawn before **GO**. It does not restart from scratch, and it does not freeze.
2. A second (or third) client on the same server hits **Play** during that lobby. They take the first bot seat: that bot model is removed, the human stands on the same spawn, and the board flips **BOT → CAT**. No second copy of the cat, no extra party. A fourth human fills the last seat. A fifth gets **This party is full — wait for the next one.**
3. **Mid-round** (intro, playing, recap) or while **CROWNED** is up: **Play** does not enter the fight and does not kick the current party. The hub toasts **Wait for the next party**. Scoring stays with the cats already in the round. **Party again** on the podium still starts a fresh lobby.
4. **Back to hub** during the lobby frees that seat. If another human is still waiting, a bot refills it. The last human to leave closes the courtyard. Leaving during a round frees the seat and does **not** drop a bot into the fight.
5. **Three micro-rounds** (not an obstacle-course clone): **YARN DODGE** (hop the coral yarn ball with **Space**; **WASD** to strafe), **STALL FREEZE** (when lanterns blink, stand on a **lit pillow**), then Dodge again.
6. Giant round titles, elim pops (`YARN BONK` / `WRONG PILLOW`), live scoreboard (**YOU / CAT / BOT**). Points: last cat standing 3, timeout survivors 2, then 1 / 0 down the elim order. After round 3: **CROWNED** podium + **Party again** or **Back to hub**.
7. Help overlay (**?** / **H**) swaps to party binds (lobby, join, late, leave). **T** emotes still work. **G** pings do not.

Seat claims live in `Shared.YarnPartyLobby` and only apply while the phase is Lobby. Scores / elims / bots are server-authoritative. Smoke: `python3 tools/test-party.py /path/to/luau`. Yarn Run, Koi Pond, Meme Arcade, and Cat Rift stay exclusive and unchanged.

### Studio live-pass (Yarn Party lobby)

1. **Solo bots.** One client → Yarn Party → Play. Seats 1–4 show YOU + LoafBot + NibBot + PurrBot. Countdown reaches GO without sticking. Three rounds, then **CROWNED** and **Party again**.
2. **Two-client lobby join.** Start the party on client A. Before GO, client B hits Play. B replaces one bot (no duplicate cat). Both boards show YOU / CAT / BOT and the same countdown. The round starts with both humans.
3. **Late join.** While a round is running (or CROWNED is up), client B hits Play. B stays in the hub with **Wait for the next party**. The live score does not gain a new cat.
4. **Leave mid-lobby.** A and B are in the lobby. B hits **Back to hub**. B's seat becomes a bot again if A is still there. When A leaves too, the courtyard closes.

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

## 4. Queue and same-server party (2+ clients)

Defaults: `MinPlayersToStart = 2`, `MatchPlaceId = 0` (match starts **in this server**), `PadQueueWithBots = true` (fill to 3 per side). Party queue does not change those defaults and does not require a reserved server.

1. Two Studio clients (Team Test / local server + players) or two published clients.
2. With no party, both hit **Queue**. HUD shows count / ETA. Two solos can land on opposite teams.
3. On **Match found** you should hear the stinger. With `MatchPlaceId = 0` (or Studio), draft starts **in place**.
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

## 5. Keybinds (after PRs 1–12)

Same list as the in-game **?** / hold **H** panel.

| Input | Action |
| --- | --- |
| **LMB** | Lock auto-attack on an enemy champ, minion, jungle, ward, or (ungated) structure |
| **X** then click | Attack-move (walk + auto-acquire) |
| **S** | Stop attack / cancel channel orders |
| **Q W E R** | Abilities. **Hold** line/dash, **release** to fire a traveling bolt (or dash). **Ground:** first press arms the ring; **LMB or same key** confirms at cursor; **Esc / RMB** cancels. Instant kits fire on press |
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
| **T** (hold) | Emote wheel (Meow, Hiss, Purr, Flex, Dance, Laugh, Cry, GG). Release or click a slice. Server cooldown; no emote while down |
| **G** (hold) | Smart ping wheel: Caution, On My Way, Assist, Enemy Missing, All Clear, Attack Here. Release or click. Team-only; cooldown. Aim at a tower/nexus/visible champ to name them |
| **Tab** (hold) | Scoreboard |
| **V** | Toggle locked follow camera |
| **Audio** (top-right) | SFX slider + mute, Music slider + mute (independent, quieter default), mute others' emotes, **Hide my name** (boards show **Anonymous Cat**). Mix + hide-name + last Practice difficulty persist (`MeoSettings_v1`) |
| **Closet** | Hub / Cat Rift wardrobe — hats + trails, yarn points (not Robux) |
| **Invite** (Cat Rift) | Same server. They **Accept** within 20s. Leader **Queue party** or **Practice with party**. **Decline**, **Leave party**, or expiry returns the line to solo |
| **?** or hold **H** | This help overlay |
| Minimap click | Generic **Attention** ping (team-only). History dots linger on the map |
| Talk prompt | Fountain / jungle NPC chat (Kitty Caster, clerks, Old Tom) |
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

- **Traveling skillshots:** Whiskers / Bytekit / Nyan Q (and other `targeting = "line"` kits) spawn a pooled neon bolt at **72 studs/s**. Damage ticks on the server as the bolt sweeps (~0.05s); the client only follows. Not hitscan.
- **Ground confirm:** first Q/W/E/R on a ground AoE shows the ring; **click or press again** casts at the cursor. **Esc / right-click / S** cancels. Lines and dashes stay **hold-to-aim, release-to-fire**.
- **Bots:** Normal/Hard lead with the same projectile speed (0.7s cap) and sidestep for `travel + 0.12s` so they still dodge the bolt instead of the old instant ray. **Jungle:** Easy never clears. Normal mid takes the nearest own-side camp only after the wave is pushed, and finishes a camp it has already hurt. Hard mid follows pigeon → golem → near crab → far crab and holds that goal between thinks (the old walker used to yank them back to lane every tick, and equidistant crabs could swap). After the route is down, Hard rotates to the furthest allied wave, with an 8-second last-known bias from team vision (allies, trinkets, pinks). Camp spots and own-side uptime are map knowledge; enemy champions are not. A hidden cat is not a target. Smoke: `python3 tools/test-jungle-bot.py /path/to/luau`.
- **Pink vs trinket:** **4** is a stealthed team-tinted pillar. **6** (after Pawmart **Control Yarn**, 2 charges) is a magenta ball enemies can see. Pinks grant a bit more team vision, slow foes in 22 studs, and keep nearby enemy trinkets revealed. Hard jungle bots still drop one free pink. Both kinds feed the server fog mask.
- **Pawmart night market:** **7** is Yarn Cleave (280g, 12-stud slash, 12s cooldown, visible enemies only). Stall Fang (300g) adds 36 raw damage to champion hits at or below 20% HP. Paper Charm (220g) ignores an enemy pink slow for 2.4s, then waits 20s. None of the three add flat damage, HP, mana, armor, or speed. Lens stays on **5**. Control Yarn still stacks to 2. Hooks live in `Shared.ItemKits`. Smoke: `python3 tools/test-items.py /path/to/luau`.
- **Fog of war:** unseen ground is a dark overlay (10-stud grid). Vision bubbles come from living ally cats, kittens, towers/nexus, trinkets, and pinks. **Keep walls** and the four **market drums** block eye-height LoS (mid gate open; thin props do not). Minimap uses the same mask. Explored-but-unseen stays a lighter tint after you leave (server match memory, restored on reconnect; not DataStore). Jungle brush hides occupants until an ally source enters that pocket. Enemy traveling bolts hide in fog; yours stay visible. Attack-move / AA will not lock an unseen brush target; attack-move walks into last-known brush. When an enemy cat, kitten, or camp leaves vision, a client ghost fades at the last spot (~1.8s) and does not follow the live body. Server owns the set; the client only paints it. Smoke: `python3 tools/test-vision.py /path/to/luau`.
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

`MapBuilder` dresses the same 420×280 bounds (lane Z −80 / 0 / 80). Each lane has an outer scratching post at `x = ±90` and an inner lantern stall at `x = ±132` (ears, yarn, wood awning, paper lanterns) before the yarn core at `x = ±168`. Stalls sit outside the keep gate and before minions cut inward (`|x| ≥ 145`). A stall is damage-gated on its own lane's post; the nexus opens only after all six structures on that side fall. Extra decor Parts are `CanCollide = false` and `CanQuery = false` so bots, tower ranges, and click-AA stay the same. The four market drums in `VisionCover` are the exception: `CanQuery = true` and `MeoBlocksVision` so fog can raycast them, still `CanCollide = false` (walk-through, same as keep walls). Client click rays exclude that folder. Lighting is a cozy night-market (`Atmosphere` + mild bloom), not a rave.

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
