"""Cat Rift HUD resource bar helper smoke. Usage: python3 tools/test-resource-bars.py /path/to/luau"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")


def wrap(name: str, rel: str) -> str:
    source = (root / rel).read_text()
    return f"local {name} = (function()\n{source}\nend)()\n"


script = (
    wrap("ResourceBars", "src/shared/ResourceBars.luau")
    + (root / "tests/resource-bars-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-resource-bars-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
