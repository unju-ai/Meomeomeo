"""Recall cancel-on-order smoke. Usage: python3 tools/test-recall.py /path/to/luau"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")

source = (root / "src/shared/RecallLogic.luau").read_text()
script = f"local RecallLogic = (function()\n{source}\nend)()\n" + (root / "tests/recall-smoke.luau").read_text()
with tempfile.TemporaryDirectory(prefix="meo-recall-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
