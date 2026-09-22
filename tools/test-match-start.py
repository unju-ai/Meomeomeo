"""Cat Rift fight-begin cue smoke.

Usage: python3 tools/test-match-start.py /path/to/luau

MatchService still stamps InProgress and startedAt together. This does not
add a freeze, and it does not move the draft timer or the wave waits.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")

match = (root / "src/server/Match/MatchService.luau").read_text()
needle = '\tcurrent.phase = "InProgress"\n\tcurrent.startedAt = Workspace:GetServerTimeNow()\n\tcurrent.phaseEndsAt = nil'
if needle not in match:
    raise SystemExit("beginFight no longer stamps InProgress and startedAt together")
if "WalkSpeed" in match:
    raise SystemExit("MatchService grew a movement freeze")
if "autoAssignChampions()\n\t\tbeginFight()" not in match:
    raise SystemExit("draft handoff no longer calls beginFight directly")

config = (root / "src/server/Config.luau").read_text()
if "ChampionSelectSeconds = 25" not in config:
    raise SystemExit("draft timer changed")
if "FirstWaveDelay = 6" not in config:
    raise SystemExit("first wave wait changed")

lines = (root / "src/shared/AnnouncerLines.luau").read_text()
if "WE ARE LIVE. Posts, then stalls, then the yarn core." not in lines:
    raise SystemExit("Kitty Caster MatchLive line changed")

juice = (root / "src/shared/MatchStartJuice.luau").read_text()
script = (
    f"local MatchStartJuice = (function()\n{juice}\nend)()\n"
    + (root / "tests/match-start-juice-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-match-start-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
