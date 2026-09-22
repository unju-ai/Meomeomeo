"""Cat Rift AFK warning smoke. Usage: python3 tools/test-afk.py /path/to/luau"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")


def wrap(name: str, rel: str) -> str:
    source = (root / rel).read_text()
    source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
    return f"local {name} = (function()\n{source}\nend)()\n"


help_src = (root / "src/client/UI/HelpPanel.luau").read_text()
if "Still there?" not in help_src or "AFK" not in help_src:
    raise SystemExit("Help overlay missing the AFK row")

playtest = (root / "PLAYTEST.md").read_text()
for phrase in ("Still there?", "45s", "90s", "AFK"):
    if phrase not in playtest:
        raise SystemExit(f"PLAYTEST.md missing AFK note: {phrase}")

match = (root / "src/server/Match/MatchService.luau").read_text()
if "AfkLogic.restoreConnected" not in match:
    raise SystemExit("rejoin must restore connected through AfkLogic")
if "matchPlayer.connected = false" not in match:
    raise SystemExit("leave must still mark the seat disconnected")
if "AFK never surrenders" not in match:
    raise SystemExit("afk path must not surrender, kick, or backfill")

init = (root / "src/server/init.server.luau").read_text()
if init.count("MatchService.noteActivity") < 12:
    raise SystemExit("move, attack, cast, ping, shop, and recall must stamp AFK")

logic = (root / "src/shared/AfkLogic.luau").read_text().lower()
for banned in ("surrender", "kick", "botservice"):
    if banned in logic:
        raise SystemExit(f"AfkLogic must not mention {banned}")

script = (
    wrap("AfkLogic", "src/shared/AfkLogic.luau")
    + wrap("RemakeLogic", "src/shared/RemakeLogic.luau")
    + wrap("ScoreboardPaint", "src/shared/ScoreboardPaint.luau")
    + (root / "tests/afk-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-afk-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
