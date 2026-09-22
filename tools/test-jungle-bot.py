"""Jungle bot route / commit / rotate / Canal Levi priority smoke.

Usage: python3 tools/test-jungle-bot.py /path/to/luau

Levi gates live in tests/jungle-bot-smoke.luau: Hard mid beats leftover camps when
UP, finishes a hurt camp first, peels a visible enemy on the pit, resumes after
death; Normal mid-river assist; Easy ignore.
"""
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


script = (
    wrap("VisionLogic", "src/shared/VisionLogic.luau")
    + wrap("RiverEpic", "src/shared/RiverEpic.luau")
    + wrap("JungleBotLogic", "src/shared/JungleBotLogic.luau")
    + (root / "tests/jungle-bot-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-jungle-bot-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
