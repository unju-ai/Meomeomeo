"""Ward place / lifetime juice smoke. Usage: python3 tools/test-ward-juice.py /path/to/luau"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
luau = Path(sys.argv[1] if len(sys.argv) > 1 else "luau")

juice = (root / "src/shared/WardJuice.luau").read_text()
script = (
    f"local WardJuice = (function()\n{juice}\nend)()\n"
    + (root / "tests/ward-juice-smoke.luau").read_text()
)
with tempfile.TemporaryDirectory(prefix="meo-ward-juice-test-") as folder:
    entry = Path(folder) / "smoke.luau"
    entry.write_text(script)
    subprocess.run([str(luau), str(entry)], check=True)
