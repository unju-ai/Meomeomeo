# Meo Meo Meo

A **cat-themed MOBA** for Roblox — every champion and NPC is a cat, lanes and nexuses are the core loop, and **voice chat is first-class**.

Players queue into a match, lock a cat champion, fight down three placeholder lanes, and try to scratch the enemy nexus to death. Teammates talk over Roblox voice (team routing when the Audio API is available). Fountain shopkeepers, a jungle coach, and a play-by-play announcer talk back through an AI chat interface that **runs on a mock provider** until you plug in a real key.

Meme stocks are a **side system**: champion tickers drift in the HUD and bump on kills. They are not the game.

This repo is a playable **scaffold** (architecture + stubs), not a finished live-ops title.

## What’s in the scaffold

- Rojo-ready `src/` layout that syncs into Roblox Studio
- Match lifecycle: **Lobby → Champion select → In progress → Ended**
- Matchmaking stub (queue for 2+ players) plus **solo practice**
- Six cat champions with Q / W / E / R ability data (server-authoritative casts)
- 3-lane map placeholder: bases, towers, nexuses, river, jungle, fountain cats
- Voice module wrapping `VoiceChatService` (team access lists, safe Studio fallback)
- AI NPC talk stubs (Pawmart clerks, Old Tom, Kitty Caster) with mock + HTTP hook
- Optional yarn / meme-stock ticker on champions
- Playful HUD: lobby, draft, ability bar, voice pill, NPC chat

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
- **Q W E R** — aim with the mouse; the server validates range, mana, cooldown, and deals damage to enemy cats and structures.
- Walk up to a blocky fountain / jungle cat and use the **Talk** prompt.

## How the MOBA loop works

```
Lobby  →  Queue / Practice  →  Champion select  →  Fight  →  Nexus down  →  Lobby
```

- **Server owns** gold, health, mana, cooldowns, structure HP, and match phase. Clients send intent (`UseAbility`, `SelectChampion`); they never set prices or wallets.
- **Teams:** Blue Whiskers vs Red Paws (`Teams` service). Practice puts you on Blue.
- **Champions:** data in `src/shared/ChampionCatalog.luau` (Chairman Meow, Nyan Rocket, Chonk Knight, Professor Whiskers, Scammy McMittens, Grandma Fluff). Same-team duplicate locks are rejected.
- **Map:** `src/server/World/MapBuilder.luau` builds a readable 3-lane placeholder (not final art). Structures are tagged parts; when a **nexus** hits 0 HP the other team wins.
- **Combat:** `CombatService` applies heals/dashes/AoE around the aim point. Tower gating / minions / vision are intentionally not in this pass.

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

## Meme stocks (side system)

`src/server/Economy/MemeStockService.luau` keeps server-authored champion tickers and a **yarn** wallet. Prices wander; kills bump the killer’s cat. The top HUD tape is cosmetic for now (`CheerTicker` remote exists for later shop/wager UI). Turn it off with `Config.Economy.Enabled = false`.

## Project layout

```
src/shared/          Types, remotes, constants, champion catalog
src/server/
  init.server.luau   Wires remotes + services
  Config.luau        Tunables + AI placeholders
  Match/             Matchmaking, match lifecycle, combat
  Voice/             VoiceChatService wrapper
  World/             3-lane map + cat NPC placeholders
  Npcs/              Catalog, mock/http AI, chat service
  Economy/           Optional meme stocks
src/client/          HUD, lobby, draft, ability bar, voice pill, NPC chat
```

Authority rule: money, prices, damage, and match state live on the server.

## Next suggested steps

1. Real cat meshes / animations and a proper camera/minimap.
2. Minion waves, tower targeting, vision, and “can’t hit nexus until inner towers are down.”
3. Item shop wired to the Pawmart clerks (gold already exists on the match player).
4. Reserved-server matchmaking + teleport; optional `GetChatGroupsAsync` so voice-compatible players land together.
5. Custom voice: push-to-talk, party chat in lobby, per-player mute UI.
6. Swap the HTTP stub for a hosted proxy so API keys never sit in the place file.
7. DataStores for cosmetics funded by yarn / meme-stock wagers.

## License / secrets

Do not commit API keys, `.env`, or `Secrets.luau`. `.gitignore` already drops Roblox binaries, Rojo sourcemaps, and secret files.
