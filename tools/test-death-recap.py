"""Death recap aggregation smoke. Usage: python3 tools/test-death-recap.py /path/to/luau"""
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


script = wrap("Types", "src/shared/Types.luau") + wrap("DamageLog", "src/shared/DamageLog.luau") + (
    root / "tests/death-recap-smoke.luau"
).read_text()
with tempfile.TemporaryDirectory(prefix="meo-death-recap-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
