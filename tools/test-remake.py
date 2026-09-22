"""Cat Rift early remake vote smoke. Usage: python3 tools/test-remake.py /path/to/luau"""
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


bot = (root / "src/server/Match/BotService.luau").read_text()
if re.search(r"[Rr]emake", bot):
    raise SystemExit("bots must not start or cast a remake vote")

help_src = (root / "src/client/UI/HelpPanel.luau").read_text()
if "F7" not in help_src or "3:00" not in help_src:
    raise SystemExit("Help overlay missing the F7 remake row")

playtest = (root / "PLAYTEST.md").read_text()
for phrase in ("F7", "3:00", "60s", "Remake"):
    if phrase not in playtest:
        raise SystemExit(f"PLAYTEST.md missing remake note: {phrase}")

match = (root / "src/server/Match/MatchService.luau").read_text()
if 'endMatch(nil, "remake")' not in match:
    raise SystemExit("remake must end through MatchService.endMatch with no winner")
if "AnnouncerService.onMatchEnd" not in match:
    raise SystemExit("remake must keep the Kitty Caster match-end hook")
if 'endMatch(winner, "surrender")' not in match:
    raise SystemExit("surrender end path must stay")

script = wrap("RemakeLogic", "src/shared/RemakeLogic.luau") + (
    root / "tests/remake-smoke.luau"
).read_text()
with tempfile.TemporaryDirectory(prefix="meo-remake-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
