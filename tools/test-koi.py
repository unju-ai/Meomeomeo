"""Koi Pond catalog smoke. Usage: python3 tools/test-koi.py /path/to/luau"""
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
    return (
        f"local {name} = (function()\n"
        "local Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }\n"
        f"{source}\nend)()\n"
    )

script = wrap("KoiCatalog", "src/shared/KoiCatalog.luau") + (root / "tests/koi-smoke.luau").read_text()
with tempfile.TemporaryDirectory(prefix="meo-koi-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
