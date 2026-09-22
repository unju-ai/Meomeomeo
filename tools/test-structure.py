"""Cat Rift structure layout + gate smoke. Usage: python3 tools/test-structure.py /path/to/luau"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")

source = (root / "src/shared/StructureLogic.luau").read_text()
script = f"local StructureLogic = (function()\n{source}\nend)()\n" + (root / "tests/structure-smoke.luau").read_text()
with tempfile.TemporaryDirectory(prefix="meo-structure-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
