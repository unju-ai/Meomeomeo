"""Cat Rift surrender vote smoke. Usage: python3 tools/test-surrender.py /path/to/luau"""
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
if re.search(r"[Ss]urrender", bot):
    raise SystemExit("bots must not start or cast a surrender vote")

help_src = (root / "src/client/UI/HelpPanel.luau").read_text()
if "F8" not in help_src or "8:00" not in help_src:
    raise SystemExit("Help overlay missing the F8 surrender row")

playtest = (root / "PLAYTEST.md").read_text()
for phrase in ("F8", "8:00", "90s", "Surrender"):
    if phrase not in playtest:
        raise SystemExit(f"PLAYTEST.md missing surrender note: {phrase}")

match = (root / "src/server/Match/MatchService.luau").read_text()
if 'endMatch(winner, "surrender")' not in match:
    raise SystemExit("surrender must end through MatchService.endMatch")
if "AnnouncerService.onMatchEnd" not in match:
    raise SystemExit("surrender must keep the Kitty Caster match-end hook")

script = wrap("SurrenderLogic", "src/shared/SurrenderLogic.luau") + (
    root / "tests/surrender-smoke.luau"
).read_text()
with tempfile.TemporaryDirectory(prefix="meo-surrender-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
