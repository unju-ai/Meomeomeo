"""Cat Rift Tab scoreboard paint helpers. Usage: python3 tools/test-scoreboard.py /path/to/luau"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")


def wrap(name: str, rel: str) -> str:
    source = (root / rel).read_text()
    return f"local {name} = (function()\n{source}\nend)()\n"


script = wrap("ScoreboardPaint", "src/shared/ScoreboardPaint.luau") + (root / "tests/scoreboard-smoke.luau").read_text()
with tempfile.TemporaryDirectory(prefix="meo-scoreboard-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
