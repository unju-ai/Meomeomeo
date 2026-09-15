"""Yarn Run catalog smoke. Usage: python3 tools/test-yarn.py /path/to/luau"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")
source = (root / "src/shared/YarnRunCatalog.luau").read_text()
source = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", source, flags=re.MULTILINE)
script = "local YarnRunCatalog = (function()\n" + source + "\nend)()\n" + (root / "tests/yarn-run-smoke.luau").read_text()
with tempfile.TemporaryDirectory(prefix="meo-yarn-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
